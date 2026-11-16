#!/usr/bin/env python3
"""TB323FU: 在编译前修正 AERA recovery 源码中与 Android 16 / 本机相关的两处。

1) twrp.cpp 里 android::keystore::copySqliteDb() 在 A16 的 keystore 源码里已不存在，
   打开 TW_INCLUDE_CRYPTO 后这行会直接编译失败。
2) kernel_module_loader.cpp 在模块加载完、/vendor 已被 overlay 之后没有等待
   module handler 完成，紧接着 mount/umount /vendor 会失败（data wipe 报错）。
   本机 rc 在 twrp.modules.loaded 动作里 setprop twrp.module.handler_done true。
"""
import sys, os, re

root = sys.argv[1] if len(sys.argv) > 1 else "."
rec = os.path.join(root, "bootable/recovery")

def read(p):
    return open(p, encoding="utf-8", errors="ignore").read()

def write(p, s):
    open(p, "w", encoding="utf-8").write(s)

changed = []

# 1) copySqliteDb
p = os.path.join(rec, "twrp.cpp")
if os.path.exists(p):
    s = read(p)
    if "android::keystore::copySqliteDb();" in s:
        s = s.replace(
            "android::keystore::copySqliteDb();",
            "// Android 16 keystore sources do not export copySqliteDb(); TB323FU build fix.",
        )
        write(p, s); changed.append("twrp.cpp: copySqliteDb removed")

# 2) wait for module handler
p = os.path.join(rec, "kernel_module_loader.cpp")
if os.path.exists(p):
    s = read(p)
    anchor = 'android::base::SetProperty(TW_MODULES_MOUNTED_PROP, "true");'
    wait = anchor + '\n\t// TB323FU: /vendor overlay must finish before the next mount/umount.\n\tandroid::base::WaitForProperty("twrp.module.handler_done", "true", std::chrono::seconds(60));'
    if anchor in s and "twrp.module.handler_done" not in s:
        s = s.replace(anchor, wait, 1)
        if "#include <chrono>" not in s:
            m = re.search(r'(?m)^#include ', s)
            s = s[:m.start()] + "#include <chrono>\n" + s[m.start():]
        write(p, s); changed.append("kernel_module_loader.cpp: wait twrp.module.handler_done")

print("TB323FU source fixes:", changed if changed else "nothing to do")
