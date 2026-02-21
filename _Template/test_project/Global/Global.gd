@tool
extends Node

var process_list: Dictionary[String, Callable]
var input_list: Dictionary[String, Callable]
var variant_list: Dictionary[String, Dictionary]


func _ready() -> void:
    editor_init()
    static_init()


func editor_init() -> void:
    if !Engine.is_editor_hint():
        return
    addVariant("editor", "viewport_3d_0", EditorInterface.get_editor_viewport_3d(0))
    addVariant("editor", "viewport_3d_1", EditorInterface.get_editor_viewport_3d(1))
    addVariant("editor", "viewport_3d_2", EditorInterface.get_editor_viewport_3d(2))
    addVariant("editor", "viewport_3d_3", EditorInterface.get_editor_viewport_3d(3))
    addVariant("editor", "main_screen", EditorInterface.get_editor_main_screen())
    for child in getVariant("editor", "main_screen").get_children():
        if child.name.begins_with("@CanvasItemEditor"):
            addVariant("editor", "CanvasItemEditor", child)
        elif child.name.begins_with("@Node3DEditor"):
            addVariant("editor", "Node3DEditor", child)


func static_init() -> void:
    Log.init()

    ThreadPool.init()


func _process(delta: float) -> void:
    for process_name in process_list.keys():
        var callback: Callable = process_list[process_name]
        if callback.is_valid():
            if callback.get_argument_count() > 0:
                callback.call(delta)
            else:
                callback.call()
        else:
            process_list.erase(process_name)


func _input(event: InputEvent) -> void:
    for key in input_list.keys():
        var callback = input_list[key]
        if callback.is_valid():
            callback.call(event)
        else:
            input_list.erase(key)


func addProcess(process_name: String, callback: Callable, overwrite: bool = false) -> void:
    if overwrite || !process_list.has(process_name):
        process_list[process_name] = callback
    else:
        Log.error("process [color=deeppink]{name}[/color] already exists", [["name", process_name]])


func removeProcess(process_name: String) -> void:
    if !process_list.has(process_name):
        Log.error("process [color=deeppink]{name}[/color] does not exist", [["name", process_name]])
        return

    process_list.erase(process_name)


func addInput(input_name: String, callback: Callable, overwrite: bool = false) -> void:
    if overwrite || !input_list.has(input_name):
        input_list[input_name] = callback
    else:
        Log.error("input [color=deeppink]{name}[/color] already exists", [["name", input_name]])


func removeInput(input_name: String) -> void:
    if !input_list.has(input_name):
        Log.error("input [color=deeppink]{name}[/color] does not exist", [["name", input_name]])
        return

    input_list.erase(input_name)


func addVariant(category: String, variant_name: String, variant: Variant, overwrite: bool = false, check_type: bool = true) -> void:
    if !variant_list.has(category):
        variant_list[category] = { }
    var list: Dictionary = variant_list[category]
    if !list.has(variant_name):
        list[variant_name] = variant
    elif overwrite:
        var old_variant: Variant = list[variant_name]
        if check_type:
            var compare_result: Array = Utils.compareVariantType(variant, old_variant)
            if !compare_result[0]:
                Log.error("variant [color=deeppink]{name}[/color] type mismatch: expected [color=gold]{expected}[/color], got [color=deeppink]{got}[/color]",
                    [["name", variant_name], ["expected", compare_result[2]], ["got", compare_result[1]]])
                return
        list[variant_name] = variant
    else:
        Log.error("variant [color=deeppink]{name}[/color] already exists", [["name", variant_name]])


func getVariant(category: String, variant_name: String, default_variant: Variant = null, output: bool = true) -> Variant:
    if !variant_list.has(category):
        if output:
            Log.error("category [color=deeppink]{name}[/color] does not exist", [["name", category]])
        return default_variant
    var list: Dictionary = variant_list[category]
    if !list.has(variant_name):
        if output:
            Log.error("variant [color=deeppink]{name}[/color] does not exist", [["name", variant_name]])
        return default_variant
    var variant: Variant = list[variant_name]
    return variant


func removeVariant(category: String, variant_name: String, output: bool = true) -> void:
    if !variant_list.has(category):
        if output:
            Log.error("category [color=deeppink]{name}[/color] does not exist", [["name", category]])
        return
    var list: Dictionary = variant_list[category]
    if !list.has(variant_name):
        if output:
            Log.error("variant [color=deeppink]{name}[/color] does not exist", [["name", variant_name]])
        return

    list.erase(variant_name)
    if list.is_empty():
        variant_list.erase(category)
