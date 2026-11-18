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

# 3) Decrypt_User: do not depend on locksettings.db for the spblob handle.
#    The device has /data/system_de/0/spblob/*.pwd even when locksettings.db
#    cannot be read from recovery.  A missing handle makes Get_Password_Type()
#    return 0, which used to make Decrypt_User() bail out before it ever tried
#    the synthetic-password path.
decrypt_p = os.path.join(root, "system/vold/Decrypt.cpp")
if os.path.exists(decrypt_p) and "aera_spblob_handle_from_dir" not in read(decrypt_p):
    s = read(decrypt_p)
    helper = r'''static std::string aera_spblob_handle_from_dir(userid_t user_id) {
    char dir_path[PATH_MAX];
    snprintf(dir_path, sizeof(dir_path), "/data/system_de/%d/spblob", user_id);
    DIR* dir = opendir(dir_path);
    if (!dir)
        return std::string();
    std::string handle;
    struct dirent* de = nullptr;
    while ((de = readdir(dir)) != nullptr) {
        const char* name = de->d_name;
        size_t len = strlen(name);
        if (len <= 4 || strcmp(name + len - 4, ".pwd") != 0)
            continue;
        handle.assign(name, len - 4);
        break;
    }
    closedir(dir);
    return handle;
}

'''
    anchor = 'inline std::string hidlVec2String'
    if anchor not in s:
        raise SystemExit("Decrypt.cpp: hidlVec2String anchor missing")
    s = s.replace(anchor, helper + anchor, 1)
    handle_re = re.compile(r'(\s*)std::string handle_str = keystore_info\.getHandle\(user_id\);')
    s, n = handle_re.subn(
        r'\1std::string handle_str = keystore_info.getHandle(user_id);\n'
        r'\1if (handle_str.empty())\n'
        r'\1    handle_str = aera_spblob_handle_from_dir(user_id);',
        s,
    )
    if n == 0:
        raise SystemExit("Decrypt.cpp: handle lookup anchor missing")
    old_gate = '    if (Get_Password_Type(user_id, filename) == 0 && !Default_Password) {'
    new_gate = ('    struct stat spblob_st;\n'
                '    bool has_spblob = (stat("/data/system_de/0/spblob", &spblob_st) == 0);\n'
                '    if (Get_Password_Type(user_id, filename) == 0 && !Default_Password && !has_spblob) {')
    if old_gate not in s:
        raise SystemExit("Decrypt.cpp: Decrypt_User gate anchor missing")
    s = s.replace(old_gate, new_gate, 1)
    write(decrypt_p, s)
    changed.append("Decrypt.cpp: spblob handle fallback + early gate bypass")

# 4) partitionmanager: wait for the real spblob directory, not the legacy key.
p = os.path.join(rec, "partitionmanager.cpp")
if os.path.exists(p):
    s = read(p)
    old_wait = '\t\tint retry_count = 10;\n\t\twhile (!TWFunc::Path_Exists("/data/system/users/gatekeeper.password.key") && --retry_count)\n\t\t\tusleep(2000); // A small sleep is needed after mounting /data to ensure reliable decrypt...maybe because of DE?'
    new_wait = '\t\tint retry_count = 10;\n\t\twhile (!TWFunc::Path_Exists("/data/system_de/0/spblob") && --retry_count)\n\t\t\tusleep(2000); // Wait for the real synthetic-password directory, not legacy gatekeeper files.'
    if old_wait in s:
        s = s.replace(old_wait, new_wait, 1)
        write(p, s); changed.append("partitionmanager.cpp: wait for /data/system_de/0/spblob")
    elif "Wait for the real synthetic-password directory" not in s:
        raise SystemExit("partitionmanager.cpp: legacy gatekeeper wait anchor missing")


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
