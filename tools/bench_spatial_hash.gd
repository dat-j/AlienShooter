extends SceneTree

## Benchmark hiệu năng SpatialHashGrid theo DoD T-301: 400 đơn vị trong
## lưới, 400 truy vấn bán kính liên tiếp, tổng thời gian phải dưới 0.5ms.
## Xem docs/05-BACKLOG.md T-301.
##
## Chạy headless:
##   godot --headless --script res://tools/bench_spatial_hash.gd
##
## LƯU Ý: script này KHÔNG được chạy được trong lúc soạn (chưa có Godot
## trên máy viết code). Số liệu in ra cần được người chạy thật xác nhận —
## xem mục "Không chắc chắn" trong báo cáo T-301.

const UNIT_COUNT: int = 400
const QUERY_COUNT: int = 400
const QUERY_RADIUS: float = 5.0
const CELL_SIZE: float = 2.0
const AREA_SIZE: float = 100.0
const BUDGET_USEC: int = 500  # 0.5ms, đo bằng micro giây


func _init() -> void:
    _run_benchmark()
    quit()


func _run_benchmark() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 12345

    var grid: SpatialHashGrid = SpatialHashGrid.new(CELL_SIZE)
    for i: int in range(UNIT_COUNT):
        var pos: Vector3 = Vector3(
            rng.randf_range(0.0, AREA_SIZE), 0.0, rng.randf_range(0.0, AREA_SIZE)
        )
        grid.insert(i, pos)

    # Buffer tái sử dụng, cấp phát một lần trước vòng đo — đúng tinh thần
    # "không cấp phát trong truy vấn" mà DoD yêu cầu.
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(UNIT_COUNT)

    var total_found: int = 0
    var start_usec: int = Time.get_ticks_usec()
    for q: int in range(QUERY_COUNT):
        var centre: Vector3 = Vector3(
            rng.randf_range(0.0, AREA_SIZE), 0.0, rng.randf_range(0.0, AREA_SIZE)
        )
        total_found += grid.query_radius(centre, QUERY_RADIUS, out)
    var elapsed_usec: int = Time.get_ticks_usec() - start_usec
    var elapsed_msec: float = float(elapsed_usec) / 1000.0
    var avg_usec_per_query: float = float(elapsed_usec) / float(QUERY_COUNT)

    print("=== Benchmark SpatialHashGrid (T-301) ===")
    print("Số đơn vị trong lưới    : %d" % UNIT_COUNT)
    print(
        (
            "Số truy vấn bán kính    : %d (bán kính %.1fm, ô %.1fm)"
            % [QUERY_COUNT, QUERY_RADIUS, CELL_SIZE]
        )
    )
    print("Tổng thời gian          : %.3f ms" % elapsed_msec)
    print("Trung bình mỗi truy vấn : %.3f us" % avg_usec_per_query)
    print("Tổng kết quả cộng dồn   : %d" % total_found)
    print("Ngân sách DoD T-301     : dưới 0.5 ms cho toàn bộ %d truy vấn" % QUERY_COUNT)
    if elapsed_usec < BUDGET_USEC:
        print("KẾT QUẢ: ĐẠT (%.3f ms < 0.5 ms)" % elapsed_msec)
    else:
        print("KẾT QUẢ: CHƯA ĐẠT (%.3f ms >= 0.5 ms)" % elapsed_msec)
