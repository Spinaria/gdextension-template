extends Logger

var mutex: Mutex = Mutex.new()

var ignore_list: Dictionary = {
    "res://Global/Static/Log.gd:print": false,
    "res://Global/Static/Log.gd:error": false,
    "res://Global/Static/File.gd:checkFile": false,
    "res://Global/Static/File.gd:checkFilePath": false,
    "res://Global/Static/File.gd:checkFolder": false,
    "res://Global/Static/File.gd:checkFolderPath": false
}


func error_to_string(error_type: int) -> String:
    match error_type:
        ErrorType.ERROR_TYPE_ERROR:
            return "[color=red]Error[/color]"
        ErrorType.ERROR_TYPE_WARNING:
            return "[color=yellow]Warning[/color]"
        ErrorType.ERROR_TYPE_SCRIPT:
            return "[color=red]Script Error[/color]"
        ErrorType.ERROR_TYPE_SHADER:
            return "[color=red]Shader Error[/color]"
        _:
            return ""


func _log_error(
    function: String,
    file: String,
    line: int,
    code: String,
    rationale: String,
    _editor_notify: bool,
    error_type: int,
    script_backtraces: Array[ScriptBacktrace]
) -> void:
    mutex.lock()

    var error_backtraces: Dictionary = {
        "error": "",
        "file": "",
        "line": 0,
        "function": "",
        "code": "",
        "rationale": "",
        "script_backtraces": []
    }

    var error_str: String = error_to_string(error_type)
    error_backtraces["error"] = error_str

    if rationale.is_empty():
        rationale = code
        code = ""

    for backtrace in script_backtraces:
        var signal_backtraces: Array = []
        for frame in range(backtrace.get_frame_count() - 1, -1, -1):
            var frame_file: String = backtrace.get_frame_file(frame)
            var frame_line: int = backtrace.get_frame_line(frame)
            var frame_function: String = backtrace.get_frame_function(frame)

            var signal_backtrace: Dictionary = {
                "file": frame_file,
                "line": frame_line,
                "function": frame_function
            }

            signal_backtraces.append(signal_backtrace)

        error_backtraces["script_backtraces"].append(signal_backtraces)

    error_backtraces["file"] = file
    error_backtraces["line"] = line
    error_backtraces["function"] = function
    error_backtraces["code"] = code
    error_backtraces["rationale"] = rationale

    output(error_backtraces)

    mutex.unlock()


func output(error_backtraces: Dictionary) -> void:
    var error: String = error_backtraces["error"]
    var file: String = error_backtraces["file"]
    var line: int = error_backtraces["line"]
    var function: String = error_backtraces["function"]
    var code: String = error_backtraces["code"]
    var rationale: String = error_backtraces["rationale"]
    var script_backtraces: Array = error_backtraces["script_backtraces"]

    var msg_backtrace: String = ""
    for script_backtrace: Array in script_backtraces:
        var index: int = 0
        var backtrace_str: String = ""
        for frame: Dictionary in script_backtrace:
            var frame_file: String = frame["file"]
            var frame_line: int = frame["line"]
            var frame_function: String = frame["function"]

            var temp_str: String = "\t[{frame}] {function} ({file}:{line})".format([
                ["frame", index],
                ["function", frame_function],
                ["file", frame_file],
                ["line", frame_line]
            ]) + "\n"

            var flag_hook: bool = false

            var ignore_function: String = frame_function
            if frame_function.ends_with("_hook"):
                flag_hook = true
                ignore_function = ignore_function.left(-5)

            var ignore_str: String = frame_file + ":" + ignore_function

            if ignore_list.has(ignore_str):
                var ignore: bool = ignore_list[ignore_str]
                if ignore:
                    continue
                else:
                    backtrace_str += "[color=webgray]{str}[/color]".format([["str", temp_str]])
            else:
                file = frame_file
                line = frame_line
                function = ignore_function
                if flag_hook:
                    backtrace_str += "[color=webgray]{str}[/color]".format([["str", temp_str]])
                else:
                    backtrace_str += temp_str

            index += 1

        msg_backtrace += backtrace_str

    var msg: String = "[color=gold][{file}:{line}::{function}][/color] [color=deeppink]{code}[/color]\n".format(
        [
            ["file", file],
            ["line", line],
            ["function", function],
            ["code", code]
        ]
    )

    msg += "{error}  [color=red]{rationale}[/color]\n".format([["error", error], ["rationale", rationale]])

    msg += msg_backtrace

    msg += "------------------------------------------------------------"

    Log.print(msg)
