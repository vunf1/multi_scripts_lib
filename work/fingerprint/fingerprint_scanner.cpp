#include <stdio.h>
#include <stdlib.h>
#include <libfprint/fprint.h>
 // winget install Microsoft.VisualStudio.2022.BuildTools --force --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22000"

void enroll_fingerprint(struct fp_dev *device) {
    printf("Place your finger on the scanner to enroll...\n");

    struct fp_print_data *data = NULL;
    int result = fp_enroll_finger(device, &data);

    if (result == FP_ENROLL_COMPLETE) {
        printf("Fingerprint enrollment complete!\n");
        if (data) {
            fp_print_data_free(data);
        }
    } else if (result == FP_ENROLL_FAIL) {
        printf("Fingerprint enrollment failed.\n");
    } else if (result == FP_ENROLL_RETRY) {
        printf("Bad scan. Please try again.\n");
    } else if (result == FP_ENROLL_RETRY_TOO_SHORT) {
        printf("Swipe too short. Try again.\n");
    } else {
        printf("Enrollment interrupted or unknown error.\n");
    }
}

int main() {
    printf("Initializing libfprint...\n");

    if (fp_init() != 0) {
        fprintf(stderr, "Failed to initialize libfprint.\n");
        return 1;
    }

    struct fp_dscv_dev **devices = fp_discover_devs();
    if (!devices) {
        fprintf(stderr, "No fingerprint devices found.\n");
        fp_exit();
        return 1;
    }

    struct fp_dscv_dev *selected_device = devices[0];
    if (!selected_device) {
        fprintf(stderr, "No fingerprint device detected.\n");
        fp_dscv_devs_free(devices);
        fp_exit();
        return 1;
    }

    printf("Opening fingerprint device...\n");
    struct fp_dev *device = fp_dev_open(selected_device);
    if (!device) {
        fprintf(stderr, "Failed to open fingerprint device.\n");
        fp_dscv_devs_free(devices);
        fp_exit();
        return 1;
    }

    printf("Fingerprint device detected: %s\n", fp_dev_get_driver(device)->name);

    enroll_fingerprint(device);

    fp_dev_close(device);
    fp_dscv_devs_free(devices);
    fp_exit();

    printf("Program finished.\n");
    return 0;
}
