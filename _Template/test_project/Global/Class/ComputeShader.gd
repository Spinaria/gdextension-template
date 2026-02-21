extends Object
class_name ComputeShader

var rd: RenderingDevice

var shader: RID
var pipeline: RID

var set_list: Dictionary[int, RID]
var uniform_list: Dictionary[String, RDUniform]
var resource_list: Dictionary[String, RID]
var persistent_resource_list: Dictionary[String, RID]

var result_index: int
var result: Dictionary[String, PackedByteArray]

var oneshot: bool


func _init(glsl_path: String, _oneshot: bool = true) -> void:
    rd = RenderingServer.get_rendering_device()

    var shader_file: RDShaderFile = load(glsl_path)
    var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

    shader = rd.shader_create_from_spirv(shader_spirv)
    pipeline = rd.compute_pipeline_create(shader)

    oneshot = _oneshot


func clear(deep: bool = false) -> void:
    for uniform_set in set_list.keys():
        var rid = set_list[uniform_set]
        if rid.is_valid():
            rd.free_rid(rid)
    set_list.clear()

    uniform_list.clear()

    for name in resource_list.keys():
        var rid = resource_list[name]
        if rid.is_valid():
            rd.free_rid(rid)
    resource_list.clear()

    if deep:
        for name in persistent_resource_list.keys():
            var rid = persistent_resource_list[name]
            if rid.is_valid():
                rd.free_rid(rid)
        persistent_resource_list.clear()


func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        clear(true)

        if pipeline.is_valid():
            rd.free_rid(pipeline)
        pipeline = RID()

        if shader.is_valid():
            rd.free_rid(shader)
        shader = RID()


func compute(x_group: int, y_group: int, z_group: int, push_constant: PackedByteArray = [], result_list: Array[String] = [], callback: Callable = Callable()) -> void:
    result.clear()
    result_index = 0

    var compute_list = rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

    for set_index in set_list.keys():
        rd.compute_list_bind_uniform_set(compute_list, set_list[set_index], set_index)

    if !push_constant.is_empty():
        rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())

    rd.compute_list_dispatch(compute_list, x_group, y_group, z_group)
    rd.compute_list_end()

    if result_list.is_empty() || !callback.is_valid():
        if oneshot:
            free.call_deferred()
        else:
            clear.call_deferred()
    else:
        getData(result_list, callback)


func getData(result_list: Array, callback: Callable) -> void:
    result_index = result_list.size()

    for index in result_list.size():
        var uniform_name = result_list[index]
        var uniform: RDUniform = getUniform(uniform_name)

        if !uniform:
            Log.error("uniform [color=deeppink]{name}[/color] does not exist", [["name", uniform_name]])
            free.call_deferred()
            return

        var ids: Array = uniform.get_ids()

        match uniform.uniform_type:
            RenderingDevice.UniformType.UNIFORM_TYPE_TEXTURE_BUFFER, \
            RenderingDevice.UniformType.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE_BUFFER, \
            RenderingDevice.UniformType.UNIFORM_TYPE_IMAGE_BUFFER, \
            RenderingDevice.UniformType.UNIFORM_TYPE_UNIFORM_BUFFER, \
            RenderingDevice.UniformType.UNIFORM_TYPE_STORAGE_BUFFER:
                rd.buffer_get_data_async(ids[-1], getDataCallback.bind(uniform_name, callback))
            RenderingDevice.UniformType.UNIFORM_TYPE_SAMPLER, \
            RenderingDevice.UniformType.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, \
            RenderingDevice.UniformType.UNIFORM_TYPE_TEXTURE, \
            RenderingDevice.UniformType.UNIFORM_TYPE_IMAGE:
                rd.texture_get_data_async(ids[-1], 0, getDataCallback.bind(uniform_name, callback))
            _:
                free.call_deferred()


func getDataCallback(array: PackedByteArray, uniform_name: String, callback: Callable) -> void:
    result[uniform_name] = array
    result_index -= 1
    if result_index == 0:
        ThreadPool.tryTask([callback.bind(result)])
        if oneshot:
            free.call_deferred()
        else:
            # clear.call_deferred()
            pass


func setResource(name: String, rid: RID, persistent: bool = false) -> void:
    var list: Dictionary = resource_list
    if persistent:
        list = persistent_resource_list

    if list.has(name):
        var old_rid: RID = list[name]
        if rid == old_rid:
            return
        elif old_rid.is_valid():
            rd.free_rid(old_rid)
    list[name] = rid
    if OS.is_stdout_verbose():
        rd.set_resource_name(rid, name)


func getResource(name: String, persistent: bool = false) -> RID:
    if persistent:
        return persistent_resource_list[name]
    else:
        return resource_list[name]


func setUniform(name: String, type: RenderingDevice.UniformType, binding: int, resources: Array) -> void:
    var uniform: RDUniform = RDUniform.new()
    uniform.uniform_type = type
    uniform.binding = binding
    for resource in resources:
        if resource is Array:
            uniform.add_id(getResource(resource[0], true))
        elif resource is RID:
            uniform.add_id(resource)
        else:
            uniform.add_id(getResource(resource))
    uniform_list[name] = uniform


func getUniform(name: String) -> RDUniform:
    return uniform_list[name]


func setUniformSet(set_index: int, uniforms: Array, cache: bool = false) -> void:
    if set_list.has(set_index):
        var rid: RID = set_list[set_index]
        if rd.uniform_set_is_valid(rid):
            rd.free_rid(rid)
        set_list.erase(set_index)

    for index in uniforms.size():
        var uniform = getUniform(uniforms[index])
        uniforms[index] = uniform

    var uniform_set: RID
    if cache:
        uniform_set = UniformSetCacheRD.get_cache(shader, set_index, uniforms)
    else:
        uniform_set = rd.uniform_set_create(uniforms, shader, set_index)

    set_list[set_index] = uniform_set
