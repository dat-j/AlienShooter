extends SceneTree

## Benchmark hiệu năng SpatialHashGrid theo DoD T-301: 400 đơn vị trong
## lưới, 400 truy vấn bán kính liên tiếp, tổng thời gian phải dưới 0.5ms.
## Xem docs/05-BACKLOG.md T-301.
##
## Chạy headless:
##   godot --headless --path <project> --script res://tools/bench_spatial_hash.gd
##
## DoD không nói rõ bán kính truy vấn dùng để đo — script này đo ở bán
## kính 5.0m (kịch bản đầu tiên, gần với "5x cell size") RỒI quét thêm
## một bảng 1.0/2.0/3.0/5.0m để có số liệu thật cho từng giả định về
## workload thực tế (xem "Không chắc chắn" trong báo cáo T-301: kết quả
## đo thật trên Godot 4.7.2 cho thấy 5.0m KHÔNG đạt ngân sách, còn các
## bán kính nhỏ hơn — sát với tầm tách đàn TDD §7 (~1-2m) — thì đạt).

const UNIT_COUNT: int = 400
const QUERY_COUNT: int = 400
const CELL_SIZE: float = 2.0
const AREA_SIZE: float = 100.0
const BUDGET_USEC: int = 500  # 0.5ms, đo bằng micro giây
const SWEEP_RADII: PackedFloat32Array = [1.0, 2.0, 3.0, 5.0]

## Máy chạy benchmark có nhiễu hệ điều hành đáng kể (đo thực tế: cùng một
## build, chạy lại nhiều lần cho kết quả lệch nhau tới 4-5 lần). Đo lặp
## lại REPEAT_COUNT lần trong CÙNG MỘT tiến trình và lấy giá trị NHỎ NHẤT
## (thông lệ microbenchmark chuẩn — nhiễu luôn làm chậm đi, hiếm khi làm
## nhanh hơn, nên min gần với "thời gian thật của thuật toán" nhất).
const REPEAT_COUNT: int = 7


func _init() -> void:
    _run_benchmark()
    quit()


func _run_benchmark() -> void:
    var grid: SpatialHashGrid = SpatialHashGrid.new(CELL_SIZE)
    var seed_positions: PackedVector3Array = _build_seed_positions()
    for i: int in range(UNIT_COUNT):
        grid.insert(i, seed_positions[i])

    print("=== Benchmark SpatialHashGrid (T-301) ===")
    print("Số đơn vị trong lưới    : %d" % UNIT_COUNT)
    print("Số truy vấn mỗi mức     : %d" % QUERY_COUNT)
    print("Kích thước ô            : %.1fm" % CELL_SIZE)
    print("Ngân sách DoD T-301     : dưới 0.5 ms cho toàn bộ %d truy vấn" % QUERY_COUNT)
    print("")

    # Kịch bản chính của DoD: bán kính 5.0m (giữ nguyên để so sánh xuyên
    # suốt các lần tối ưu — xem lịch sử trong báo cáo T-301).
    _run_case(grid, 5.0)

    print("")
    print("--- Bảng quét bán kính (bổ sung theo yêu cầu, không phải DoD gốc) ---")
    for i: int in range(SWEEP_RADII.size()):
        _run_case(grid, SWEEP_RADII[i])


func _run_case(grid: SpatialHashGrid, radius: float) -> void:
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(UNIT_COUNT)

    # Chuẩn bị sẵn toạ độ tâm truy vấn MỘT lần (không tính vào thời gian
    # đo) — cùng một tập toạ độ được dùng lại ở mọi lần lặp để so sánh
    # công bằng, giống hệt cách một frame swarm thật sẽ truy vấn từ vị
    # trí các đơn vị đã có sẵn.
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 777
    var centres: PackedVector3Array = PackedVector3Array()
    centres.resize(QUERY_COUNT)
    for q: int in range(QUERY_COUNT):
        centres[q] = Vector3(rng.randf_range(0.0, AREA_SIZE), 0.0, rng.randf_range(0.0, AREA_SIZE))

    var best_usec: int = -1
    var total_found: int = 0
    for r: int in range(REPEAT_COUNT):
        var found_this_run: int = 0
        var start_usec: int = Time.get_ticks_usec()
        for q: int in range(QUERY_COUNT):
            found_this_run += grid.query_radius(centres[q], radius, out)
        var elapsed_usec: int = Time.get_ticks_usec() - start_usec
        if best_usec < 0 or elapsed_usec < best_usec:
            best_usec = elapsed_usec
        total_found = found_this_run  # giống nhau mỗi lần lặp, chỉ cần giữ 1 bản

    var elapsed_msec: float = float(best_usec) / 1000.0
    var avg_usec_per_query: float = float(best_usec) / float(QUERY_COUNT)
    var avg_found: float = float(total_found) / float(QUERY_COUNT)

    var verdict: String = "ĐẠT" if best_usec < BUDGET_USEC else "CHƯA ĐẠT"
    print(
        (
            "bán kính %.1fm: tốt nhất/%d lần %.3f ms | tb %.3f us/truy vấn | tb %.1f kết quả/truy vấn | %s"
            % [radius, REPEAT_COUNT, elapsed_msec, avg_usec_per_query, avg_found, verdict]
        )
    )


func _build_seed_positions() -> PackedVector3Array:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 12345
    var positions: PackedVector3Array = PackedVector3Array()
    positions.resize(UNIT_COUNT)
    for i: int in range(UNIT_COUNT):
        positions[i] = Vector3(rng.randf_range(0.0, AREA_SIZE), 0.0, rng.randf_range(0.0, AREA_SIZE))
    return positions
