extends RefCounted
class_name File

################################################## checkFilePath ##################################################
static func checkFilePath(file: String, extension: String = "", output: bool = true) -> bool:
    var file_extension: String = file.get_extension()
    if !file.is_absolute_path() || file_extension.is_empty():
        if output:
            Log.error("file [color=deeppink]{file}[/color] is invalid", [["file", file]])
        return false
    if !extension.is_empty() && file_extension.to_lower() != extension.to_lower():
        if output:
            Log.error("file [color=deeppink]{file}[/color] extension mismatch: expected [color=gold]{expected}[/color], got [color=deeppink]{got}[/color]",
                [
                    ["file", file],
                    ["expected", extension],
                    ["got", file_extension]
                ])
        return false
    return true
################################################## checkFile ##################################################
static func checkFile(file: String, extension: String = "", output: bool = true) -> bool:
    if !checkFilePath(file, extension, output):
        return false
    if !FileAccess.file_exists(file):
        if output:
            Log.error("file [color=deeppink]{file}[/color] does not exist", [["file", file]])
        return false
    return true
################################################## checkFolderPath ##################################################
static func checkFolderPath(folder: String, output: bool = true) -> bool:
    if !folder.is_absolute_path() || !folder.get_extension().is_empty():
        if output:
            Log.error("folder [color=deeppink]{folder}[/color] is invalid", [["folder", folder]])
        return false
    return true
################################################## checkFolder ##################################################
static func checkFolder(folder: String, allow_create: bool = false, output: bool = true) -> bool:
    if !checkFolderPath(folder, output):
        return false
    if !DirAccess.dir_exists_absolute(folder):
        if !allow_create:
            if output:
                Log.error("folder [color=deeppink]{folder}[/color] does not exist", [["folder", folder]])
            return false
        var err = DirAccess.make_dir_recursive_absolute(folder)
        if err != OK:
            if output:
                Log.error(error_string(err), ": [color=deeppink]{folder}[/color]", [["folder", folder]])
            return false
    return true
################################################## getAllFiles ##################################################
static func getAllFiles(folder: String, ignore_extension: Array[String] = [], ignore_folder: Array[String] = [], ignore_files: Array[String] = [], out_path: String = "", out_result: Dictionary = { }) -> Dictionary:
    if !checkFolder(folder):
        return { }

    var dir = DirAccess.open(folder)
    if dir:
        dir.list_dir_begin()
        var file_name: String = dir.get_next()
        while !file_name.is_empty():
            var temp_path = out_path.path_join(file_name)
            var file_path: String = dir.get_current_dir().path_join(file_name)
            if dir.current_is_dir():
                if !ignore_folder.has(temp_path):
                    out_result = getAllFiles(file_path, ignore_extension, ignore_folder, ignore_files, temp_path, out_result)
            elif !ignore_extension.has(temp_path.get_extension()) && !ignore_files.has(temp_path):
                out_result[temp_path] = file_name
            file_name = dir.get_next()
    else:
        Log.error(error_string(DirAccess.get_open_error()), ": [color=deeppink]{folder}[/color]", [["folder", folder]])

    return out_result
################################################## getFolderFiles ##################################################
static func getFolderFiles(folder: String, ignore_extension: Array[String] = [], ignore_folder: Array[String] = [], ignore_files: Array[String] = []) -> Dictionary:
    var result: Dictionary = {
        "file": { },
        "folder": { }
    }

    if !checkFolder(folder):
        return result

    var dir = DirAccess.open(folder)
    if dir:
        dir.list_dir_begin()
        var file_name: String = dir.get_next()
        while !file_name.is_empty():
            var file_path: String = dir.get_current_dir().path_join(file_name)
            if dir.current_is_dir():
                if !ignore_folder.has(file_name):
                    result["folder"][file_path] = file_name
            elif !ignore_extension.has(file_name.get_extension()) && !ignore_files.has(file_name):
                result["file"][file_path] = file_name
            file_name = dir.get_next()
    else:
        Log.error(error_string(DirAccess.get_open_error()), ": [color=deeppink]{folder}[/color]", [["folder", folder]])

    return result
################################################## saveFile ##################################################
static func saveFile(path: String, buffer: PackedByteArray, output: bool = true) -> bool:
    if !checkFilePath(path):
        return false
    var save_dir: String = path.get_base_dir()
    if !checkFolder(save_dir, true):
        return false

    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        if !file.store_buffer(buffer):
            Log.error("save file : [color=deeppink]{path}[/color] failed", [["path", path]])
            return false
        file.close()
    else:
        Log.error(error_string(FileAccess.get_open_error()), ": [color=deeppink]{path}[/color]", [["path", path]])
        return false

    if output:
        Log.print("save file: [color=green]{path}[/color]", [["path", path]])

    return true
################################################## getLocalizationStr ##################################################
static func getLocalizationStr(folder: String = "res://", ignore_extension: Array[String] = ["uid"], ignore_folder: Array[String] = [".godot", ".vscode", "addons", "Test", "userdata"], ignore_files: Array[String] = []) -> Dictionary:
    if !checkFolder(folder, false, false):
        return { }

    var result: Dictionary = {
        "str": { },
        "gds_str": { },
        "log_print": { },
        "log_error": { }
    }

    var file_list: Dictionary = getAllFiles(folder, ignore_extension, ignore_folder, ignore_files)

    var reg_str: RegEx = RegEx.new()
    var pattern_str: String = r'"(S_[A-Z0-9_]+)"'
    reg_str.compile(pattern_str)

    var reg_print: RegEx = RegEx.new()
    var pattern_print: String = r'Log\.print\(\s*"((?:\\.|[^"\\])*)"'
    reg_print.compile(pattern_print)

    var reg_error: RegEx = RegEx.new()
    var pattern_error: String = r'Log\.error\(\s*"((?:\\.|[^"\\])*)"'
    reg_error.compile(pattern_error)

    for temp_path: String in file_list.keys():
        var path: String = folder.path_join(temp_path)
        match path.get_extension():
            "tscn":
                # process tscn
                var packed_tscn: PackedScene = load(path)
                var tscn_state: SceneState = packed_tscn.get_state()

                for index in tscn_state.get_node_count():
                    for jndex in tscn_state.get_node_property_count(index):
                        var value: Variant = tscn_state.get_node_property_value(index, jndex)

                        if typeof(value) == TYPE_STRING:
                            if value == value.to_upper() && value.contains("_"):
                                result["str"][value] = ""

            "gd":
                # process gd
                var gds_code: String = FileAccess.get_file_as_string(path)

                # search gds_str
                var reg_result: Array[RegExMatch] = reg_str.search_all(gds_code)
                for match_result: RegExMatch in reg_result:
                    var msgid: String = match_result.get_string(1)
                    result["gds_str"][msgid] = ""

                # search log_print
                reg_result = reg_print.search_all(gds_code)
                for match_result: RegExMatch in reg_result:
                    var msgid: String = match_result.get_string(1)
                    result["log_print"][msgid] = ""

                # search log_error
                reg_result = reg_error.search_all(gds_code)
                for match_result: RegExMatch in reg_result:
                    var msgid: String = match_result.get_string(1)
                    result["log_error"][msgid] = ""

    for key in result.keys():
        var list: Dictionary = result[key]
        list.sort()

    return result
################################################## getLocalizationStrFromPo ##################################################
static func getLocalizationStrFromPo(path: String) -> Dictionary:
    if !checkFile(path, "po", false):
        return { }

    var po_text: String = FileAccess.get_file_as_string(path)

    var result: Dictionary = {
        "lang": "",
        "str": { }
    }

    var reg: RegEx = RegEx.new()
    var pattern_head: String = r'msgid\s*""\s*msgstr\s*""\s*"Language:\s*([A-Za-z0-9_-]+)'
    reg.compile(pattern_head)

    var head_result = reg.search(po_text)
    if !head_result:
        return result

    result["lang"] = head_result.get_string(1)

    var pattern_msg: String = r'msgid\s*"((?:\\.|[^"\\])*)"\s*msgstr\s*"((?:\\.|[^"\\])*)"'
    reg.compile(pattern_msg)

    var msg_result: Array[RegExMatch] = reg.search_all(po_text)
    for msg: RegExMatch in msg_result:
        var msgid: String = msg.get_string(1)
        if msgid.is_empty():
            continue
        var msgstr: String = msg.get_string(2)
        result["str"][msgid] = msgstr

    return result
################################################## generatePo ##################################################
static func generatePo(path: String, language: String = "en") -> void:
    if !checkFilePath(path, "po", false):
        return

    var str_list: Dictionary = getLocalizationStr()
    var po_list: Dictionary = getLocalizationStrFromPo(path)

    if !po_list.is_empty():
        if !po_list["lang"].is_empty():
            if language.is_empty():
                language = po_list["lang"]
            elif language != po_list["lang"]:
                Log.error("po file [color=deeppink]{path}[/color] language mismatch: expected [color=gold]{expected}[/color], got [color=deeppink]{got}[/color]", [
                    ["path", path],
                    ["expected", po_list["lang"]],
                    ["got", language]
                ])
                return

    if language.is_empty():
        Log.error("language is empty")
        return

    if po_list.has("str"):
        po_list = po_list["str"]
    else:
        po_list.clear()

    var text: String = "msgid \"\"\nmsgstr \"\"\n\"Language: {language}\"\n\n\n".format([["language", language]])

    for key in str_list.keys():
        if !str_list[key].is_empty():
            if language == "en" && (key == "log_print" || key == "log_error"):
                continue
            text += "# {key}\n".format([["key", key]])
        for msgid in str_list[key].keys():
            var msgstr: String = str_list[key][msgid]
            if po_list.has(msgid):
                msgstr = po_list[msgid]
            text += "msgid \"" + msgid + "\"\n"
            text += "msgstr \"" + msgstr + "\"\n\n"

    saveFile(path, text.to_utf8_buffer())
