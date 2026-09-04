extends GutTest

## Kiểm tra khung test chạy được. Xem docs/05-BACKLOG.md T-004.


func test_gut_chay_duoc() -> void:
    assert_true(true, "khung test GUT phải chạy")


func test_project_dung_ten() -> void:
    var ten: String = str(ProjectSettings.get_setting("application/config/name"))
    assert_eq(ten, "IRONHIVE", "tên project phải là IRONHIVE")


func test_renderer_la_forward_plus() -> void:
    var rm: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
    assert_eq(rm, "forward_plus", "renderer phải là Forward+ theo TDD §1")
