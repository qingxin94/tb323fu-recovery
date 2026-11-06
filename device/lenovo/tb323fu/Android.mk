#
# Copyright (C) 2026 The AERA Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),tb323fu)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
