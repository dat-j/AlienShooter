extends SceneTree

## Công cụ debug: nạp một scene, chạy vài frame rồi lưu ảnh viewport ra PNG.
## Dùng để kiểm tra thật sự render ra cái gì mà không cần ngồi nhìn cửa sổ.
##
##   godot --path <dự án> --script res://tools/capture_frame.gd
##
## KHÔNG chạy với --headless: headless không có thiết bị render nên ảnh sẽ rỗng.
## Ảnh nằm ở user://capture.png (Windows: %APPDATA%/Godot/app_userdata/IRONHIVE).

const SCENE_PATH: String = "res://scenes/main/test_arena.tscn"
const OUT_PATH: String = "user://capture.png"
const WARMUP_FRAMES: int = 30


func _initialize() -> void:
    var packed: PackedScene = load(SCENE_PATH) as PackedScene
    if packed == null:
        printerr("Không nạp được ", SCENE_PATH)
        quit()
        return
    root.add_child(packed.instantiate())
    _run.call_deferred()


func _run() -> void:
    for _i: int in range(WARMUP_FRAMES):
        await process_frame
    var image: Image = root.get_texture().get_image()
    print("SAVED ", ProjectSettings.globalize_path(OUT_PATH), " err=", image.save_png(OUT_PATH))
    _print_scene_diagnostics()
    quit()


## In ra những thứ hay hỏng thầm lặng: không có camera, đèn chiếu sai chiều.
func _print_scene_diagnostics() -> void:
    var camera: Camera3D = root.get_viewport().get_camera_3d()
    print("CAMERA=", "KHÔNG CÓ" if camera == null else str(camera.global_position))
    for node: Node in root.find_children("*", "DirectionalLight3D", true, false):
        var light: DirectionalLight3D = node as DirectionalLight3D
        var direction: Vector3 = -light.global_transform.basis.z
        print("LIGHT %s energy=%.2f dir=%s %s" % [
            light.name, light.light_energy, direction,
            "(CHIẾU NGƯỢC LÊN TRỜI)" if direction.y > 0.0 else ""
        ])
