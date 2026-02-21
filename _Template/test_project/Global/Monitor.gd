extends RefCounted
class_name Monitor

################################################## stopwatch ##################################################
static func stopwatch(function: Callable) -> void:
    var timer: StopWatch = StopWatch.new(function.get_object().to_string())
    timer.start(function.get_method())
    function.call()
    timer.stop()


class StopWatch:
    var name: String = ""
    var sub_name: String = ""

    var start_time: int


    func _init(_name: String = "") -> void:
        if !_name.is_empty():
            name = " " + _name


    func start(_sub_name: String = "") -> void:
        if !_sub_name.is_empty():
            sub_name = " - " + _sub_name
        start_time = Time.get_ticks_usec()


    func stop() -> void:
        var stop_time: int = Time.get_ticks_usec()

        var value: String = str((stop_time - start_time) / 1000.0)

        print_rich("StopWatch[color=green]{name}[/color][color=green]{sub_name}[/color]: [color=gold]{time}[/color] ms".format([
            ["name", name],
            ["sub_name", sub_name],
            ["time", value]
        ])
        )
