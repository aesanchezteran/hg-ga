import json
import random

# =========================================
# PARAMETERS
# =========================================
NTASKS = 64
NPROCS = 16
BENCHMARKS = 300

PERIOD_MIN = 1
PERIOD_MAX = 100

# -------------------------
# Utilization mode:
# "fixed"  -> all tasksets use FIXED_UTIL
# "list"   -> use UTIL_LIST[b]
# "range"  -> random uniform in [UTIL_MIN, UTIL_MAX]
# -------------------------
UTIL_MODE = "fixed"

FIXED_UTIL = 0.5 * NPROCS

# Example for UTIL_MODE = "list"
UTIL_LIST = [
    0.4 * NPROCS,
    0.5 * NPROCS,
    0.6 * NPROCS,
    0.7 * NPROCS,
    0.8 * NPROCS,
]

# Example for UTIL_MODE = "range"
UTIL_MIN = 0.4 * NPROCS
UTIL_MAX = 0.9 * NPROCS

JSON_OUT = "tasksets_300_5.json"
SVH_OUT  = "tasksets_300_5.svh"

random.seed(42)


# =========================================
# UUniFast
# =========================================
def uunifast(n, U_total):
    utilizations = []
    sumU = U_total

    for i in range(1, n):
        nextSum = sumU * (random.random() ** (1 / (n - i)))
        utilizations.append(sumU - nextSum)
        sumU = nextSum

    utilizations.append(sumU)
    return utilizations


# =========================================
# UTIL HELPERS
# =========================================
def get_target_util(benchmark_idx):
    if UTIL_MODE == "fixed":
        return FIXED_UTIL

    elif UTIL_MODE == "list":
        return UTIL_LIST[benchmark_idx % len(UTIL_LIST)]

    elif UTIL_MODE == "range":
        return random.uniform(UTIL_MIN, UTIL_MAX)

    else:
        raise ValueError(f"Unknown UTIL_MODE: {UTIL_MODE}")


def compute_utilization(taskset):
    return sum(t["exec"] / t["deadline"] for t in taskset)


def average_execution_time(taskset):
    return sum(t["exec"] for t in taskset) / len(taskset)


# =========================================
# TASKSET GENERATOR
# =========================================
def generate_taskset(target_util):
    utilizations = uunifast(NTASKS, target_util)
    tasks = []

    for u in utilizations:
        period = random.randint(PERIOD_MIN, PERIOD_MAX)

        exec_time = max(1, int(u * period))
        deadline = period

        tasks.append({
            "exec": exec_time,
            "deadline": deadline
        })

    return tasks


# =========================================
# PRINTING
# =========================================
def print_sv_dataset(taskset):
    exec_vals = ", ".join(str(t["exec"]) for t in taskset)
    ddl_vals  = ", ".join(str(t["deadline"]) for t in taskset)

    print("exec_tbl = '{%s};" % exec_vals)
    print("dead_tbl = '{%s};" % ddl_vals)


# =========================================
# EXPORT JSON
# =========================================
def export_json(all_benchmarks, filename):
    with open(filename, "w") as f:
        json.dump(all_benchmarks, f, indent=2)
    print(f"Saved JSON to {filename}")


# =========================================
# EXPORT SYSTEMVERILOG
# Utilizations are exported scaled by 1000
# =========================================
def export_svh(all_benchmarks, filename):
    all_tasksets = [b["tasks"] for b in all_benchmarks]

    max_exec = max(t["exec"] for ts in all_tasksets for t in ts)
    max_dead = max(t["deadline"] for ts in all_tasksets for t in ts)
    max_util_scaled = max(int(round(b["actual_util"] * 1000)) for b in all_benchmarks)

    exec_w = max(1, max_exec.bit_length())
    ddl_w  = max(1, max_dead.bit_length())
    util_w = max(1, max_util_scaled.bit_length())

    with open(filename, "w") as f:
        f.write("// Auto-generated taskset include file\n")
        f.write(f"localparam int BENCHMARKS = {len(all_benchmarks)};\n")
        f.write(f"localparam int NTASKS     = {len(all_tasksets[0])};\n")
        f.write(f"localparam int EXEC_W     = {exec_w};\n")
        f.write(f"localparam int DDL_W      = {ddl_w};\n")
        f.write(f"localparam int UTIL_W     = {util_w};\n\n")

        f.write("logic [EXEC_W-1:0] exec_sets [BENCHMARKS][NTASKS] = '{\n")
        for b, bench in enumerate(all_benchmarks):
            row = ", ".join(str(t["exec"]) for t in bench["tasks"])
            comma = "," if b < len(all_benchmarks) - 1 else ""
            f.write(f"    '{{{row}}}{comma}\n")
        f.write("};\n\n")

        f.write("logic [DDL_W-1:0] dead_sets [BENCHMARKS][NTASKS] = '{\n")
        for b, bench in enumerate(all_benchmarks):
            row = ", ".join(str(t["deadline"]) for t in bench["tasks"])
            comma = "," if b < len(all_benchmarks) - 1 else ""
            f.write(f"    '{{{row}}}{comma}\n")
        f.write("};\n\n")

        f.write("logic [UTIL_W-1:0] util_target_x1000 [BENCHMARKS] = '{")
        f.write(", ".join(str(int(round(b["target_util"] * 1000))) for b in all_benchmarks))
        f.write("};\n")

        f.write("logic [UTIL_W-1:0] util_actual_x1000 [BENCHMARKS] = '{")
        f.write(", ".join(str(int(round(b["actual_util"] * 1000))) for b in all_benchmarks))
        f.write("};\n")

    print(f"Saved SystemVerilog include to {filename}")


# =========================================
# MAIN
# =========================================
def main():
    all_benchmarks = []

    total_system_util = 0.0
    total_processor_util = 0.0

    for b in range(BENCHMARKS):
        target_util = get_target_util(b)
        taskset = generate_taskset(target_util)
        actual_util = compute_utilization(taskset)
        processor_util = actual_util / NPROCS

        all_benchmarks.append({
            "benchmark": b,
            "target_util": target_util,
            "actual_util": actual_util,
            "tasks": taskset
        })

        total_system_util += actual_util
        total_processor_util += processor_util

        print("\n==============================")
        print("Benchmark", b + 1)
        print("==============================")
        print("Target System Utilization =", round(target_util, 4))
        print("Actual System Utilization =", round(actual_util, 4))
        print("Actual Processor Utilization =", round(processor_util, 4))
        print("Average Task Execution Time =", round(average_execution_time(taskset), 2))

        print("\nDataset (exec, deadline):")
        for i, t in enumerate(taskset):
            print(f"Task {i:02d}: exec={t['exec']:3} deadline={t['deadline']:3}")

    avg_system_util = total_system_util / BENCHMARKS
    avg_processor_util = total_processor_util / BENCHMARKS

    print("\n=================================")
    print("AVERAGE UTILIZATION RESULTS")
    print("=================================")
    print("Average System Utilization =", round(avg_system_util, 4))
    print("Average Processor Utilization =", round(avg_processor_util, 4))

    export_json(all_benchmarks, JSON_OUT)
    export_svh(all_benchmarks, SVH_OUT)


if __name__ == "__main__":
    main()