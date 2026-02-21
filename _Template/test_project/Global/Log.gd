extends RefCounted
class_name Log

static var logger: Logger:
    set(v):
        var obj = G.getVariant("Log", "logger", null, false)
        if obj is not Logger:
            G.addVariant("Log", "logger", v, true, false)
            OS.add_logger(v)
        elif v != obj:
            OS.remove_logger(obj)
            G.addVariant("Log", "logger", v, true, false)
            OS.add_logger(v)
    get:
        return G.getVariant("Log", "logger", null, false)

static func init() -> void:
    logger = load("res://Global/Class/Logger.gd").new()

################################################## error ##################################################
static func error(...args) -> void:
    var text = parse.callv(args)
    push_error(text)
################################################## print ##################################################
static func print(...args) -> void:
    var text = parse.callv(args)

    if Engine.is_editor_hint():
        print_rich(text)
        return
    elif OS.has_feature("editor"):
        print_rich(text)

################################################## parse ##################################################
static func parse(...args) -> String:
    var reg = RegEx.new()
    var pattern = r'.*{[\w_]+}.*'
    reg.compile(pattern)

    var result: String = ""

    var index: int = 0
    while index < args.size():
        var arg = args[index]
        if arg is String:
            if index + 1 < args.size() && reg.search(arg):
                var value = args[index + 1]
                if value is Dictionary || value is Array || value is Object:
                    result += arg.format(value)
                    index += 1
            else:
                result += arg
        elif arg is Object:
            result += arg.to_string()
        elif arg is Dictionary:
            result += Utils.dictionaryToString(arg)
        elif arg is Array:
            result += Utils.arrayToString(arg)
        else:
            result += str(arg)

        index += 1

    return result
