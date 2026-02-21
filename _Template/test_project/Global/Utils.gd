extends RefCounted
class_name Utils

enum StringSearchMode {
    Contains,
    Containsn,
    Prefix,
    Prefixn,
    Suffix,
    Suffixn
}

#region object
################################################## getNodeType ##################################################
static func getObjectType(obj: Object) -> String:
    if !obj:
        Log.error("obj is invalid")
        return ""

    var script: Script
    if obj is Script:
        script = obj
    else:
        script = obj.get_script()

    while script:
        var obj_class: String = script.get_global_name()
        if !obj_class.is_empty():
            return obj_class
        script = script.get_base_script()

    return obj.get_class()
################################################## compareVariant ##################################################
static func compareVariantType(var1: Variant, var2: Variant) -> Array:
    var type_var1 = typeof(var1)
    var type_var2 = typeof(var2)

    if type_var1 != type_var2:
        return [false, type_string(type_var1), type_string(type_var2)]

    if type_var1 == TYPE_OBJECT:
        var class_var1 = getObjectType(var1)
        var class_var2 = getObjectType(var2)
        if class_var1 != class_var2:
            return [false, class_var1, class_var2]
        else:
            return [true, class_var1, class_var2]

    return [true, type_string(type_var1), type_string(type_var2)]
################################################## isSubClassOf ##################################################
static func isSubClassOf(obj: Object, base_class: String) -> bool:
    if !obj:
        Log.error("obj is invalid")
        return false

    var script: Script
    if obj is Script:
        script = obj
    else:
        script = obj.get_script()

    while script:
        var obj_class: String = script.get_global_name()
        if obj_class == base_class:
            return true
        script = script.get_base_script()

    return false
################################################## matchString ##################################################
static func matchString(source_text: String, text: String, search_mode: StringSearchMode = StringSearchMode.Contains) -> bool:
    match search_mode:
        StringSearchMode.Contains:
            if source_text.contains(text):
                return true
        StringSearchMode.Containsn:
            if source_text.containsn(text):
                return true
        StringSearchMode.Prefix:
            if source_text.begins_with(text):
                return true
        StringSearchMode.Prefixn:
            if source_text.to_lower().begins_with(text.to_lower()):
                return true
        StringSearchMode.Suffix:
            if source_text.ends_with(text):
                return true
        StringSearchMode.Suffixn:
            if source_text.to_lower().ends_with(text.to_lower()):
                return true

    return false
#endregion
#region node
################################################## pause ##################################################
static func pause(node: Node) -> void:
    if node.can_process():
        node.process_mode = Node.ProcessMode.PROCESS_MODE_DISABLED
    else:
        node.process_mode = Node.ProcessMode.PROCESS_MODE_INHERIT
################################################## renameNodeInEditor ##################################################
static func renameNode(node: Node, new_name: String) -> void:
    if node.name == new_name:
        return
    if !Engine.is_editor_hint():
        var undoredo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
        undoredo.create_action("Rename Node")
        undoredo.add_do_property(node, "name", new_name)
        undoredo.add_undo_property(node, "name", node.name)
        undoredo.commit_action()
    else:
        node.name = new_name
################################################## setOwner ##################################################
static func setOwner(node: Node, child: Node) -> void:
    if node.owner == null:
        child.owner = node
    else:
        child.owner = node.owner
    for obj in child.get_children():
        setOwner(node, obj)
################################################## getOwner ##################################################
static func getOwner(node: Node) -> Node:
    var temp_owner = node
    while temp_owner:
        node = temp_owner
        temp_owner = node.owner

    return node
################################################## getChild ##################################################
static func getChild(parent: Node, child_name: String, child_class: String) -> Node:
    if child_name.is_empty() && child_class.is_empty():
        return null

    for child in parent.get_children():
        if child_name.is_empty():
            if child.get_class() == child_class:
                return child
        elif child.name == child_name:
            if child_class.is_empty():
                return child
            elif child.get_class() == child_class:
                return child

        var result = getChild(child, child_name, child_class)
        if result:
            return result

    return null
################################################## getChildren ##################################################
static func getChildren(anchor: Node, current: Node, out_result: Dictionary = { }) -> Dictionary:
    for child in current.get_children():
        out_result[anchor.get_path_to(child)] = child
        getChildren(anchor, child, out_result)

    return out_result
################################################## getChildrenByName ##################################################
static func getChildrenByName(anchor: Node, current: Node, text: String, search_mode: StringSearchMode = StringSearchMode.Contains) -> Dictionary:
    var result: Dictionary = { }
    var children = getChildren(anchor, current)
    for child_path in children.keys():
        var child = children[child_path]
        if matchString(child.name, text, search_mode):
            result[child_path] = child

    return result
################################################## hasChildByName ##################################################
static func hasChildByName(node: Node, text: String, search_mode: StringSearchMode = StringSearchMode.Contains) -> bool:
    for child in node.get_children():
        if matchString(child.name, text, search_mode):
            return true

        if hasChildByName(child, text, search_mode):
            return true

    return false

#endregion
#region containers
################################################## dictionaryToString ##################################################
static func dictionaryToString(dic: Dictionary, str_array: bool = false, out_indentation: String = "", out_result: String = "", out_key: String = "", out_comma: String = "") -> String:
    if out_key:
        out_result += out_indentation + str(out_key) + ": {\n"
    else:
        out_result += out_indentation + "{\n"
    var next_indentation: String = out_indentation + "\t"
    for index in dic.keys().size():
        var key: Variant = dic.keys()[index]
        var comma: String = ","
        if index == dic.keys().size() - 1:
            comma = ""
        if key is String:
            out_key = "\"" + key + "\""
        else:
            out_key = str(key)
        var value: Variant = dic[key]
        if value is Dictionary:
            out_result = dictionaryToString(value, str_array, next_indentation, out_result, out_key, comma)
        elif value is Array:
            if str_array:
                out_result = arrayToString(value, str_array, next_indentation, out_result, out_key, comma)
            else:
                out_result += next_indentation + out_key + ": " + str(value) + comma + "\n"
        else:
            if value is String:
                value = "\"" + value + "\""
            else:
                value = str(value)
            out_result += next_indentation + out_key + ": " + value + comma + "\n"
    out_result += out_indentation + "}" + out_comma + "\n"
    return out_result
################################################## arrayToString ##################################################
static func arrayToString(arr: Array, str_dic: bool = true, out_indentation: String = "", out_result: String = "", out_key: String = "", out_comma: String = "") -> String:
    if out_key:
        out_result += out_indentation + out_key + ": [\n"
    else:
        out_result += out_indentation + "[\n"
    var next_indentation: String = out_indentation + "\t"
    for index in arr.size():
        var comma: String = ","
        if index == arr.size() - 1:
            comma = ""
        var content: Variant = arr[index]
        if content is Array:
            out_result = arrayToString(content, str_dic, next_indentation, out_result, comma)
        elif content is Dictionary:
            if str_dic:
                out_result = dictionaryToString(content, str_dic, next_indentation, out_result, comma)
            else:
                out_result += next_indentation + str(content) + comma + "\n"
        else:
            if content is String:
                content = "\"" + content + "\""
            else:
                content = str(content)
            out_result += next_indentation + content + comma + "\n"
    out_result += out_indentation + "]" + out_comma + "\n"
    return out_result
################################################## dictionaryFindKeys ##################################################
static func dictionaryFindKeys(dic: Dictionary, name: String, sort: bool = true) -> Array:
    var result: Array = []
    for key in dic.keys():
        if key is String:
            if name.is_subsequence_ofn(key):
                result.append(key)
    if sort:
        result.sort()
    return result
################################################## arrayFindKeys ##################################################
static func arrayFindKeys(arr: Array, name: String, sort: bool = true) -> Array:
    var result: Array = []
    for obj in arr:
        if obj is String:
            if name.is_subsequence_ofn(obj):
                result.append(obj)
    if sort:
        result.sort()
    return result
################################################## dictionaryAddKey ##################################################
static func dictionaryAddKey(dic: Dictionary, key_path: Array, key_value: Array = []) -> bool:
    for index in key_path.size():
        var key = key_path[index]
        if !dic.has(key):
            dic[key] = { }
        elif dic[key] is not Dictionary:
            return false
        dic = dic[key]
    if key_value.size() == 2:
        dic[key_value[0]] = key_value[1]
    return true
################################################## dictionaryDeleteKey ##################################################
static func dictionaryDeleteKey(dic: Dictionary, key_path: Array) -> bool:
    var out_list: Array
    out_list.resize(key_path.size())
    out_list[0] = dic

    var temp_list: Dictionary = dic
    for index in key_path.size():
        var key: Variant = key_path[index]
        if !temp_list.has(key):
            return false
        var value: Variant = temp_list[key]
        if index != key_path.size() - 1:
            if value is not Dictionary:
                return false
            out_list[index + 1] = value
            temp_list = value

    var flag_delete: bool = true
    for index in range(out_list.size() - 1, -1, -1):
        var list: Dictionary = out_list[index]
        var key: Variant = key_path[index]

        if flag_delete:
            list.erase(key)
            if list.is_empty():
                flag_delete = true
            else:
                flag_delete = false
        else:
            break

    return true
################################################## projectionToMat4 ##################################################
static func projectionToMat4(projection: Projection) -> Array:
    return [
        projection.x.x, projection.x.y, projection.x.z, projection.x.w,
        projection.y.x, projection.y.y, projection.y.z, projection.y.w,
        projection.z.x, projection.z.y, projection.z.z, projection.z.w,
        projection.w.x, projection.w.y, projection.w.z, projection.w.w
    ]
################################################## tranform3DToMat4 ##################################################
static func tranform3DToMat4(transform: Transform3D) -> Array:
    return [
        transform.basis.x.x, transform.basis.x.y, transform.basis.x.z, 0.0,
        transform.basis.y.x, transform.basis.y.y, transform.basis.y.z, 0.0,
        transform.basis.z.x, transform.basis.z.y, transform.basis.z.z, 0.0,
        transform.origin.x, transform.origin.y, transform.origin.z, 1.0
    ]

#endregion
#region input
################################################## getActionString ##################################################
static func getActionString(action: String) -> Array:
    var result: Array = []
    var events = InputMap.action_get_events(action)
    result.resize(events.size())
    for index in events.size():
        var event = events[index]
        result[index] = event.as_text()

    return result
################################################## getActionKeycode ##################################################
static func getActionKeycode(action: String) -> Array:
    var result: Array = []
    var events = InputMap.action_get_events(action)
    result.resize(events.size())
    for index in events.size():
        var event = events[index]
        var keycode = OS.find_keycode_from_string(event.as_text())
        result[index] = keycode

    return result
################################################## getInputEventFromString ##################################################
static func getInputEventFromString(key: String, checked: bool = false) -> InputEvent:
    if !checked && !checkInputString(key):
        return null

    var event: InputEvent
    if key.containsn("Mouse "):
        event = InputEventMouseButton.new()
        event.pressed = true

        if key.containsn("Shift"):
            event.shift_pressed = true
        if key.containsn("Ctrl"):
            event.ctrl_pressed = true
        if key.containsn("Alt"):
            event.alt_pressed = true
        if key.containsn(" DoubleClick"):
            event.double_click = true
        if key.containsn(" Released"):
            event.pressed = false

        var mouse_button: Array = [
            "Mouse L",
            "Mouse R",
            "Mouse M",
            "Mouse WU",
            "Mouse WD",
            "Mouse WL",
            "Mouse WR",
            "Mouse T1",
            "Mouse T2"
        ]

        for index in mouse_button.size():
            if key.containsn(mouse_button[index]):
                event.button_index = index + 1
    else:
        event = InputEventKey.new()
        event.pressed = true
        if key.containsn("Shift+"):
            event.shift_pressed = true
            key = key.replacen("Shift+", "")
        if key.containsn("Ctrl+"):
            event.ctrl_pressed = true
            key = key.replacen("Ctrl+", "")
        if key.containsn("Alt+"):
            event.alt_pressed = true
            key = key.replacen("Alt+", "")
        if key.containsn(" Released"):
            event.pressed = false
            key = key.replacen(" Released", "")
        if key.containsn(" Echo"):
            event.echo = true
            key = key.replacen(" Echo", "")
        event.keycode = OS.find_keycode_from_string(key)

    return event
################################################## checkInputEvent ##################################################
static func checkInputString(key: String) -> bool:
    if key.containsn("Mouse "):
        # check modifier
        var mouse_modifier: Array = [
            "Shift+",
            "Ctrl+",
            "Alt+"
        ]
        for s in mouse_modifier:
            var count = key.countn(s)
            if count > 1:
                return false
            key = key.replacen(s, "")
        # check extra modifier
        var extra_modifier: Array = [
            " DoubleClick",
            " Released"
        ]
        var find_extra_modifier: bool = false
        for s in extra_modifier:
            var count = key.countn(s)
            if count > 1:
                return false
            elif count == 1:
                if find_extra_modifier:
                    return false
                find_extra_modifier = true
                key = key.replacen(s, "")
        # check mouse button
        var mouse_button: Array = [
            "Mouse L",
            "Mouse R",
            "Mouse M",
            "Mouse WU",
            "Mouse WD",
            "Mouse WL",
            "Mouse WR",
            "Mouse T1",
            "Mouse T2"
        ]
        var find_mouse_button: bool = false
        for s in mouse_button:
            var count = key.countn(s)
            if count > 1:
                return false
            elif count == 1:
                if find_mouse_button:
                    return false
                find_mouse_button = true
                key = key.replacen(s, "")
        if !find_mouse_button:
            return false
        # final check
        if !key.is_empty():
            return false
    else:
        var key_modifier: Array = [
            " Released",
            " Echo"
        ]
        var find_modifier: bool = false
        for s in key_modifier:
            var count = key.countn(s)
            if count > 1:
                return false
            elif count == 1:
                if find_modifier:
                    return false
                find_modifier = true
                key = key.replacen(s, "")
        var keycode = OS.find_keycode_from_string(key)
        if keycode == 0:
            return false

    return true
################################################## matchInputEvent ##################################################
static func matchInputEvent(shortcut: Shortcut, event: InputEvent) -> bool:
    for shortcut_event: InputEvent in shortcut.events:
        if event.is_match(shortcut_event):
            if event is InputEventMouseButton:
                if shortcut_event.is_pressed() == event.is_pressed() && \
                    shortcut_event.double_click == event.double_click:
                        return true
            else:
                if shortcut_event.is_echo() && event.is_pressed():
                    return true
                elif !event.is_echo() && shortcut_event.is_pressed() == event.is_pressed():
                    return true

    return false

#endregion
