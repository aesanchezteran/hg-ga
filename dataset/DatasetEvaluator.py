import json
import heapq
import numpy as np
import csv

NPROCS = 16
BENCHMARKS_FILE = "Dataset/tasksets_300_9.json"


def compute_metrics(results):
    response_times = []
    turnaround_times = []
    dlms = 0

    for task in results:
        rt = task["start"]     # arrival assumed 0
        tat = task["finish"]   # arrival assumed 0

        response_times.append(rt)
        turnaround_times.append(tat)

        if task["finish"] > task["deadline"]:
            dlms += 1

    ART = sum(response_times) / len(response_times)
    ATAT = sum(turnaround_times) / len(turnaround_times)
    return ART, ATAT, dlms


def average_execution_time(taskset):
    return sum(t["exec"] for t in taskset) / len(taskset)


def load_benchmarks(filename):
    with open(filename, "r") as f:
        return json.load(f)


# -----------------------------
# EDF
# -----------------------------
def schedule_edf(tasks):

    time = 0
    ready = tasks.copy()

    for t in ready:
        t["remaining"] = t["exec"]

    running = []
    finished = []

    while ready or running:

        ready.sort(key=lambda x: x["deadline"])

        while len(running) < NPROCS and ready:
            task = ready.pop(0)

            task["start"] = time

            heapq.heappush(running,
                (time + task["remaining"], id(task), task))

        if not running:
            time += 1
            continue

        finish_time, _, task = heapq.heappop(running)

        time = finish_time
        task["finish"] = finish_time

        finished.append(task)

    return finished

# -----------------------------
# LLF
# -----------------------------

def schedule_llf(tasks):

    time = 0
    tasks = tasks.copy()

    for t in tasks:
        t["remaining"] = t["exec"]

    running = []
    finished = []

    while tasks or running:

        tasks.sort(key=lambda x: (x["deadline"] - time - x["remaining"]))

        while len(running) < NPROCS and tasks:
            task = tasks.pop(0)

            task["start"] = time

            heapq.heappush(running,
                (time + task["remaining"], id(task), task))

        if not running:
            time += 1
            continue

        finish_time, _, task = heapq.heappop(running)

        time = finish_time
        task["finish"] = finish_time

        finished.append(task)

    return finished


# -----------------------------
# EFSBA-like heuristic
# -----------------------------
def schedule_efsba(tasks):

    time = 0
    tasks = tasks.copy()

    # initialize remaining execution
    for t in tasks:
        t["remaining"] = t["exec"]

    running = []
    finished = []

    while tasks or running:

        # Fuzzy priority:
        # lower value = higher priority
        tasks.sort(key=lambda x: (0.7 * x["deadline"] + 0.3 * x["remaining"]))

        # fill processors
        while len(running) < NPROCS and tasks:

            task = tasks.pop(0)

            # record start time if first execution
            if "start" not in task:
                task["start"] = time

            heapq.heappush(
                running,
                (time + task["remaining"], id(task), task)
            )

        if not running:
            time += 1
            continue

        finish_time, _, task = heapq.heappop(running)

        time = finish_time
        task["finish"] = finish_time

        finished.append(task)

    return finished

def write_metrics_header(writer):
    writer.writerow([
        "benchmark",
        "target_util",
        "actual_util",
        "processor_util",
        "art",
        "atat",
        "dlm"
    ])


def dump_metrics_row(writer, benchmark_idx, target_util, actual_util, processor_util, metrics):
    art, atat, dlm = metrics
    writer.writerow([
        benchmark_idx,
        target_util,
        actual_util,
        processor_util,
        art,
        atat,
        dlm
    ])

def stats_metrics(metrics_list):
        arr = np.array(metrics_list)

        mean = np.mean(arr, axis=0)
        std  = np.std(arr, axis=0, ddof=1)
        var  = np.var(arr, axis=0, ddof=1)

        return mean, std, var

def main():
    MAX_BENCHMARKS = 300

    all_benchmarks = load_benchmarks(BENCHMARKS_FILE)
    all_benchmarks = all_benchmarks[:MAX_BENCHMARKS]

    total_system_util = 0.0
    total_processor_util = 0.0

    edf_all = []
    llf_all = []
    efs_all = []

    with open("EDF_metrics_6.csv", "w", newline="") as f_edf, \
         open("LLF_metrics_6.csv", "w", newline="") as f_llf, \
         open("EFSB_metrics_6.csv", "w", newline="") as f_efs:

        edf_writer = csv.writer(f_edf)
        llf_writer = csv.writer(f_llf)
        efs_writer = csv.writer(f_efs)

        write_metrics_header(edf_writer)
        write_metrics_header(llf_writer)
        write_metrics_header(efs_writer)

        for bench in all_benchmarks:
            b = bench["benchmark"]
            taskset = bench["tasks"]
            target_util = bench["target_util"]
            actual_util = bench["actual_util"]

            processor_util = actual_util / NPROCS
            total_system_util += actual_util
            total_processor_util += processor_util

            edf_res = schedule_edf([t.copy() for t in taskset])
            llf_res = schedule_llf([t.copy() for t in taskset])
            efs_res = schedule_efsba([t.copy() for t in taskset])

            edf_metrics = compute_metrics(edf_res)
            llf_metrics = compute_metrics(llf_res)
            efs_metrics = compute_metrics(efs_res)

            edf_all.append(edf_metrics)
            llf_all.append(llf_metrics)
            efs_all.append(efs_metrics)

            dump_metrics_row(edf_writer, b, target_util, actual_util, processor_util, edf_metrics)
            dump_metrics_row(llf_writer, b, target_util, actual_util, processor_util, llf_metrics)
            dump_metrics_row(efs_writer, b, target_util, actual_util, processor_util, efs_metrics)

    avg_system_util = total_system_util / len(all_benchmarks)
    avg_processor_util = total_processor_util / len(all_benchmarks)

    print("\n=================================")
    print("AVERAGE UTILIZATION RESULTS")
    print("=================================")
    print("Average System Utilization =", round(avg_system_util, 4))
    print("Average Processor Utilization =", round(avg_processor_util, 4))

    print("\n=================================")
    print("AVERAGE SCHEDULER RESULTS")
    print("=================================")

    edf_mean, edf_std, edf_var = stats_metrics(edf_all)
    llf_mean, llf_std, llf_var = stats_metrics(llf_all)
    efs_mean, efs_std, efs_var = stats_metrics(efs_all)

    print("\nEDF RESULTS")
    print("Mean -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(edf_mean))
    print("STD  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(edf_std))
    print("VAR  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(edf_var))

    print("\nLLF RESULTS")
    print("Mean -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(llf_mean))
    print("STD  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(llf_std))
    print("VAR  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(llf_var))

    print("\nEFSB RESULTS")
    print("Mean -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(efs_mean))
    print("STD  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(efs_std))
    print("VAR  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(efs_var))

    with open("Scheduler_summary_9.csv", "w", newline="") as f_summary:
        writer = csv.writer(f_summary)
        writer.writerow(["scheduler", "stat", "art", "atat", "dlm"])

        writer.writerow(["EDF",  "mean", *edf_mean])
        writer.writerow(["EDF",  "std",  *edf_std])
        writer.writerow(["EDF",  "var",  *edf_var])

        writer.writerow(["LLF",  "mean", *llf_mean])
        writer.writerow(["LLF",  "std",  *llf_std])
        writer.writerow(["LLF",  "var",  *llf_var])

        writer.writerow(["EFSB", "mean", *efs_mean])
        writer.writerow(["EFSB", "std",  *efs_std])
        writer.writerow(["EFSB", "var",  *efs_var])

    print("\nCSV files generated:")
    print("  EDF_metrics.csv")
    print("  LLF_metrics.csv")
    print("  EFSB_metrics.csv")
    print("  Scheduler_summary.csv")

    # for bench in all_benchmarks:
    #     b = bench["benchmark"]
    #     taskset = bench["tasks"]
    #     target_util = bench["target_util"]
    #     actual_util = bench["actual_util"]

    #     processor_util = actual_util / NPROCS
    #     total_system_util += actual_util
    #     total_processor_util += processor_util

    #     # print("\n==============================")
    #     # print("Benchmark", b + 1)
    #     # print("==============================")
    #     # print("Target Utilization =", round(target_util, 4))
    #     # print("Actual Utilization =", round(actual_util, 4))
    #     # print("Processor Utilization =", round(processor_util, 4))
    #     # print("Average Task Execution Time =", round(average_execution_time(taskset), 2))

    #     edf_res = schedule_edf([t.copy() for t in taskset])
    #     llf_res = schedule_llf([t.copy() for t in taskset])
    #     efs_res = schedule_efsba([t.copy() for t in taskset])

    #     edf_metrics = compute_metrics(edf_res)
    #     llf_metrics = compute_metrics(llf_res)
    #     efs_metrics = compute_metrics(efs_res)

    #     edf_all.append(edf_metrics)
    #     llf_all.append(llf_metrics)
    #     efs_all.append(efs_metrics)

    #     # print("\nMetrics:")
    #     # print("EDF  -> ART %.2f ATAT %.2f DLM %d" % edf_metrics)
    #     # print("LLF  -> ART %.2f ATAT %.2f DLM %d" % llf_metrics)
    #     # print("EFSB -> ART %.2f ATAT %.2f DLM %d" % efs_metrics)

    # avg_system_util = total_system_util / len(all_benchmarks)
    # avg_processor_util = total_processor_util / len(all_benchmarks)

    # print("\n=================================")
    # print("AVERAGE UTILIZATION RESULTS")
    # print("=================================")
    # print("Average System Utilization =", round(avg_system_util, 4))
    # print("Average Processor Utilization =", round(avg_processor_util, 4))

    # print("\n=================================")
    # print("AVERAGE SCHEDULER RESULTS")
    # print("=================================")

    # edf_mean, edf_std, edf_var = stats_metrics(edf_all)
    # llf_mean, llf_std, llf_var = stats_metrics(llf_all)
    # efs_mean, efs_std, efs_var = stats_metrics(efs_all)

    # print("\nEDF RESULTS")
    # print("Mean -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(edf_mean))
    # print("STD  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(edf_std))
    # print("VAR  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(edf_var))

    # print("\nLLF RESULTS")
    # print("Mean -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(llf_mean))
    # print("STD  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(llf_std))
    # print("VAR  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(llf_var))

    # print("\nEFSB RESULTS")
    # print("Mean -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(efs_mean))
    # print("STD  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(efs_std))
    # print("VAR  -> ART %.4f  ATAT %.4f  DLM %.4f" % tuple(efs_var))


if __name__ == "__main__":
    main()