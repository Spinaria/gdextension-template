extends RefCounted
class_name ThreadPool

enum ThreadState {
    Idle,
    Running,
    Finished
}

static var pool: Array:
    set(v):
        G.addVariant("ThreadPool", "pool", v, true, false)
    get:
        var list = G.getVariant("ThreadPool", "pool", null, false)
        if list is not Array:
            list = []
            G.addVariant("ThreadPool", "pool", list, true, false)
        return list

static var load_pool: Dictionary:
    set(v):
        G.addVariant("ThreadPool", "load_pool", v, true, false)
    get:
        var list = G.getVariant("ThreadPool", "load_pool", null, false)
        if list is not Dictionary:
            list = { }
            G.addVariant("ThreadPool", "load_pool", list, true, false)
        return list

static func init() -> void:
    var thread_count: int = -1
    if thread_count < 0:
        thread_count = maxi(0, OS.get_processor_count() - 1)

    pool.resize(thread_count)
    for index in pool.size():
        var thread_unit: ThreadUnit = ThreadUnit.new()
        pool[index] = thread_unit

    G.addProcess("ThreadPool", update)

################################################## update ##################################################
static func update() -> void:
    for unit in pool:
        unit.update()
    for path in load_pool.keys():
        var progress: Array = []
        var status = ResourceLoader.load_threaded_get_status(path, progress)
        match status:
            ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
                Log.error("resource [color=deeppink]{path}[/color] is invalid", [["path", path]])
                load_pool.erase(path)
            ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
                var value: float = progress[0]
                var check_callback: Callable = load_pool[path]["check_callback"]
                if check_callback.is_valid():
                    check_callback.call(value)
            ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
                Log.error("resource [color=deeppink]{path}[/color] load failed", [["path", path]])
                load_pool.erase(path)
            ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
                var callback: Callable = load_pool[path]["callback"]
                if callback.is_valid():
                    callback.call(ResourceLoader.load_threaded_get(path))
                load_pool.erase(path)
################################################## getAvailableThread ##################################################
static func getAvailableThread() -> ThreadUnit:
    for unit in pool:
        if unit.state() == ThreadState.Idle:
            return unit
    return null
################################################## getAllAvailableThread ##################################################
static func getAllAvailableThread() -> Array:
    var result: Array = []
    for unit in pool:
        if unit.state() == ThreadState.Idle:
            result.append(unit)
    return result
################################################## createTask ##################################################
static func createTask(function_list: Array[Callable], callback: Callable = Callable(), continuity: bool = true) -> bool:
    var unit: ThreadUnit = getAvailableThread()
    if !unit:
        return false

    Task.new(unit, function_list, callback, continuity)

    return true
################################################## createGroupTask ##################################################
static func createGroupTask(function: Callable, elements: int, callback: Callable = Callable()) -> bool:
    var unit_list: Array = getAllAvailableThread()
    if unit_list.is_empty():
        return false

    GroupTask.new(unit_list, function, elements, callback)
    return true
################################################## tryTask ##################################################
static func tryTask(function_list: Array[Callable], callback: Callable = Callable(), continuity: bool = true) -> void:
    if createTask(function_list, callback, continuity):
        return

    var result: Variant = null
    for index in function_list.size():
        var function: Callable = function_list[index]
        if function.is_valid():
            if index != 0 && continuity && function.get_argument_count() > 0:
                result = function.call(result)
            else:
                result = function.call()

    if callback.is_valid():
        if continuity && callback.get_argument_count() > 0:
            callback.call(result)
        else:
            callback.call()
################################################## tryGroupTask ##################################################
static func tryGroupTask(function: Callable, elements: int, callback: Callable = Callable()) -> void:
    if createGroupTask(function, elements, callback):
        return

    var group_result: Array = []
    group_result.resize(elements)
    for index in elements:
        group_result[index] = function.call(index)

    if callback.is_valid():
        if callback.get_argument_count() > 0:
            callback.call(group_result)
        else:
            callback.call()
################################################## loadResource ##################################################
static func loadResource(path: String, callback: Callable, check_callback: Callable = Callable(), use_sub_threads: bool = false, type_hint: String = "", cache_mode: ResourceLoader.CacheMode = ResourceLoader.CacheMode.CACHE_MODE_REUSE) -> void:
    if load_pool.has(path):
        Log.error("resource [color=deeppink]{path}[/color] is loading", [["path", path]])
        return
    if !callback.is_valid():
        Log.error("callback is invalid")
        return

    load_pool[path] = {
        "callback": callback,
        "check_callback": check_callback
    }

    var err = ResourceLoader.load_threaded_request(path, type_hint, use_sub_threads, cache_mode)
    if err != OK:
        Log.error(error_string(err), ": [color=deeppink]{path}[/color]", [["path", path]])
        return


class ThreadUnit:
    signal finished
    var thread: Thread


    func _init() -> void:
        thread = Thread.new()


    func start(function: Callable) -> void:
        if state() == ThreadState.Idle:
            thread.start(function)


    func state() -> ThreadState:
        if thread.is_started():
            if !thread.is_alive():
                return ThreadState.Finished
            return ThreadState.Running
        return ThreadState.Idle


    func update() -> void:
        match state():
            ThreadState.Finished:
                var result: Variant = thread.wait_to_finish()
                finished.emit(result)


    func get_id() -> String:
        return thread.get_id()


class Task extends Object:
    var thread_unit: ThreadUnit

    var function_list: Array
    var function_index: int

    var callback: Callable

    var continuity: bool = false


    func _init(unit: ThreadUnit, _function_list: Array, _callback: Callable, _continuity: bool = false) -> void:
        thread_unit = unit
        thread_unit.finished.connect(_on_thread_finished)

        function_list = _function_list
        callback = _callback
        continuity = _continuity

        start()


    func start(function: Callable = function_list[function_index]) -> void:
        thread_unit.start(function)


    func _on_thread_finished(result: Variant) -> void:
        function_index += 1
        if function_index == function_list.size():
            thread_unit.finished.disconnect(_on_thread_finished)
            if callback.is_valid():
                if callback.get_argument_count() > 0:
                    callback.call(result)
                else:
                    callback.call()
            free.call_deferred()
        else:
            var function = function_list[function_index]
            if continuity && function.get_argument_count() > 0:
                function = function.bind(result)

            start(function)


class GroupTask extends Object:
    var thread_unit_list: Array
    var thread_unit_count: int

    var wait_count: int
    var called_count: int

    var function: Callable
    var elements: int
    var element_count: int

    var callback: Callable
    var group_result: Array


    func _init(unit_list: Array, _function: Callable, _elements: int, _callback: Callable) -> void:
        thread_unit_list.resize(ThreadPool.pool.size() - 1)
        for index in unit_list.size():
            if thread_unit_count >= ThreadPool.pool.size() - 1:
                break
            var thread_unit = unit_list[index]
            thread_unit_list[index] = thread_unit
            thread_unit_count += 1

        function = _function
        elements = _elements
        callback = _callback

        group_result.resize(elements)

        start()


    func addThreadUnit() -> void:
        var thread_unit: ThreadUnit = ThreadPool.getAvailableThread()
        if !thread_unit || thread_unit_list.has(thread_unit):
            return

        thread_unit_list[thread_unit_count] = thread_unit
        thread_unit_count += 1


    func start() -> void:
        if thread_unit_count < ThreadPool.pool.size() - 1:
            addThreadUnit()

        if wait_count != 0:
            return

        wait_count = mini(elements - called_count, thread_unit_count)

        for index in wait_count:
            if element_count == elements:
                break

            var thread_unit = thread_unit_list[index]
            if thread_unit.state() != ThreadState.Idle:
                continue

            Task.new(thread_unit, [function.bind(element_count)], task_callback.bind(element_count))
            element_count += 1


    func task_callback(result: Variant, index: int) -> void:
        group_result[index] = result
        wait_count -= 1
        called_count += 1

        if called_count == elements && wait_count == 0:
            if callback.is_valid():
                if callback.get_argument_count() > 0:
                    callback.call(group_result)
                else:
                    callback.call()
            free.call_deferred()
        elif wait_count == 0:
            start()
