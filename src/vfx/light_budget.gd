class_name LightBudget
extends RefCounted

## Ngân sách đèn tạm dùng chung toàn game. Xem docs/02-TDD.md §12.6:
## muzzle flash, vụ nổ và mọi đèn ngắn hạn khác **không được đổ bóng**, và
## không bao giờ được có quá 12 cái sáng cùng lúc.
##
## Class tĩnh — không khởi tạo. Bộ đếm là `static var` nên nó thật sự là
## một ngân sách chung, không phải mỗi hệ thống một ngân sách riêng.
##
## Hợp đồng: ai `request()` thành công thì PHẢI `release()` đúng một lần khi
## đèn tắt. Node pooled trả đèn trong `_on_released()`.

const MAX_TEMPORARY_LIGHTS: int = 12

static var _active: int = 0


## Xin một suất đèn. False nghĩa là đã hết ngân sách — người gọi phải chạy
## hiệu ứng KHÔNG có đèn chứ không được bỏ luôn hiệu ứng.
static func request() -> bool:
    if _active >= MAX_TEMPORARY_LIGHTS:
        return false
    _active += 1
    return true


static func release() -> void:
    _active = maxi(_active - 1, 0)


static func get_active_count() -> int:
    return _active


static func has_room() -> bool:
    return _active < MAX_TEMPORARY_LIGHTS


## Dọn sạch khi đổi màn hoặc trong teardown của test.
static func reset() -> void:
    _active = 0
