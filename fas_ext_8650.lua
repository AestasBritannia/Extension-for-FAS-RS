API_VERSION = 2

function set_sf_backdoor(level)
    os.execute(string.format("service call SurfaceFlinger 1035 i32 %u 2>&1 >/dev/null", level))
end

function irisConfig(parameters)
    os.execute(string.format("irisConfig %s 2>&1 >/dev/null", parameters))
end

function set_current_governor(cpunum, governor)
    local file = io.open(string.format("/sys/devices/system/cpu/cpufreq/policy%u/scaling_governor", cpunum))
    io.output(file)
    io.write(governor)
    io.close(file)
end

function disable_qcom_sleep(param)
    local file = io.open("/sys/devices/system/cpu/qcom_lpm/parameters/sleep_disabled")
    io.output(file)
    io.write(param)
    io.close(file)
end

function enable_boost_freq()
    local file = io.open("/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq")
    io.output(file)
    io.write(3302400)
    io.close(file)
end

function disable_freq_limit(value)
    local file = io.open(string.format("/proc/game_opt/disable_cpufreq_limit"))
    io.output(file)
    io.write(value)
    io.close(file)
end

function l3_boost_freq(value)
    local file = io.open(string.format("/sys/devices/system/cpu/bus_dcvs/L3/boost_freq"))
    io.output(file)
    io.write(value)
    io.close(file)
end

function core_ctl_enable(cpunum, value)
    local ctl_table = {
        [1111] = {0, 2, 5, 7},
        [0111] = {2, 5, 7},
        [0110] = {2, 5},
        [0011] = {5, 7},
        [0101] = {2, 7}
    }
    
    local core_num = ctl_table[cpunum] and ctl_table[cpunum] or {7}
    local value = value == 0 and 9 or 0
    
    for _, i in ipairs(core_num) do
        local file = io.open(string.format("/sys/devices/system/cpu/cpu%u/core_ctl/enable", i), "w")
        if file then
            file:write(value)
            file:close()
            local filei = io.open(string.format("/sys/devices/system/cpu/cpu%u/core_ctl/min_cpus", i), "w")
            if filei then
                filei:write(string.format("%u", value))
                filei:close()
            end
        end
    end
end

function set_governor(gov0, gov2, gov5, gov7)
    set_current_governor(0, gov0)
    set_current_governor(2, gov2)
    set_current_governor(5, gov5)
    set_current_governor(7, gov7)
end

function set_offset(policy0, policy2, policy5, policy7)
    set_policy_freq_offset(0, policy0)
    set_policy_freq_offset(2, policy2)
    set_policy_freq_offset(5, policy5)
    set_policy_freq_offset(7, policy7)
end

function touch_sampling_rate(rate)
    local rate_id = {
        [125] = 0,
        [240] = 1
    }    
    local rate_num = rate_id[rate] or 0    
    os.execute(string.format("touchHidlTest -c wo 0 26 %u 2>&1 >/dev/null", rate_num))
end

function gov_param_set(cpunum, parameter, value)
    local cpunum_ranges = {
        [1111] = {0, 2, 5, 7},
        [0111] = {2, 5, 7},
        [0110] = {2, 5},
        [0011] = {5, 7},
        [0101] = {2, 7}
    }

    local range = cpunum_ranges[cpunum]
    if not range then
        range = {cpunum}
    end

    for _, i in ipairs(range) do
        local gov_file = io.open(string.format("/sys/devices/system/cpu/cpufreq/policy%u/scaling_governor", i), "r")
        local governor = gov_file:read()
        gov_file:close()

        local file_path = string.format("/sys/devices/system/cpu/cpufreq/policy%u/%s/%s", i, governor, parameter)
        local file = io.open(file_path, "w")
        file:write(value)
        file:close()
    end
end

function cosa_surgery(pkg)
    local sqlite3_path = "/data/adb/modules/fas_ext/sqlite3"
    local db_path = "/data/data/com.oplus.cosa/databases/db_game_database"

    local command = string.format([[
%s %s << EOF
UPDATE [PackageConfigBean]
SET [cpu_config]='%s', [gpu_config]='%s', [gpa_config]='%s', [game_zone]='%s', [thermal_frame]='%s', [fps_stabilizer]='%s', [refresh_rate]='%s', [resv_8]='%s', [resv_13]='%s', [unity_game_boost]='%s'
WHERE ([PackageConfigBean].[package_name] = '%s');
.quit
EOF
]], sqlite3_path, db_path, cpu_config, gpu_config, gpa_config, game_zone, thermal_frame, fps_stabilizer, refresh_rate, resv_8, resv_13, unity_game_boost, pkg)

    os.execute(command)
end

function iris_preset_disable()
    set_sf_backdoor(0)
    irisConfig("258 1 0")
    irisConfig("273 1 0")
    irisConfig("56 1 1")
end

function iris_memc_enable(osd_disable, latency, original_fps, target_fps)
    osd_disable = osd_disable ~= 0 and 1 or osd_disable
        
    local latency_values = {
        normal = 18,
        low = 34,
        ultra_low = 50
    }
    
    local target_fps_values = {
        [60] = 1,
        [90] = 2,
        [120] = 3
    }
    
    local latency_num = latency_values[latency] or 18
    local sf_backdoor_value = target_fps_values[target_fps] or 3
    
    set_sf_backdoor(sf_backdoor_value)
    irisConfig(string.format("258 6 10 -1 %u -1 %u %u 2>&1 >/dev/null", latency_num, osd_disable, original_fps))
end

function iris_sr_enable(preset_id, sr_type)
    sr_type = sr_type ~= 1 and 2 or sr_type
    os.execute(string.format("irisConfig 273 3 1 %u %u 2>&1 >/dev/null", preset_id, sr_type))
end

function gov_preset_0()
    disable_qcom_sleep(0)
    disable_freq_limit(0)
    enable_boost_freq()
    core_ctl_enable(1111, 1)
    gov_param_set(1111, "stall_aware", 1)
    gov_param_set(1111, "max_stall_reduce_of_util", 3)
    gov_param_set(1111, "up_rate_limit_us", 1000)
    gov_param_set(1111, "down_rate_limit_us", 1000)
    gov_param_set(0111, "reduce_pct_of_stall", 90)
end

function gov_preset_1()
    disable_qcom_sleep(1)
    disable_freq_limit(1)
    core_ctl_enable(1111, 0)
    gov_param_set(1111, "stall_aware", 1)
    gov_param_set(1111, "max_stall_reduce_of_util", 0)
    gov_param_set(1111, "up_rate_limit_us", 0)
    gov_param_set(1111, "down_rate_limit_us", 0)
    gov_param_set(0111, "reduce_pct_of_stall", 100)
end

function gov_preset_2()
    disable_qcom_sleep(1)
    core_ctl_enable(1111, 0)
    disable_freq_limit(1)
    set_governor("uag", "performance", "performance", "performance")
end

function load_fas(pid, pkg)
    if (pkg == "com.miHoYo.Yuanshen" or pkg == "com.miHoYo.ys.mi" or pkg == "com.miHoyo.ys.bilibili" or pkg == "com.miHoYo.GenshinImpact") then
        cpu_config = '{"sceneswitch":{"boost":"","time":10000},"start":{"boost":"","time":30000}}'
        gpu_config = '{"630":{"c0":-1,"c1":-1,"c2":-1,"c3":-1,"fps":-1}}'
        refresh_rate = '{"clickOpt":false,"moveOpt":false, "debugOpt":true}'
        gpa_config = '{"cl":12,"ch":19,"sm":14,"gm":20,"tl":-1,"th":17,"core":"-1,-1,-1,-1,-1,-1,-1,-1","mtl":"80,80,80,80","fast":"95,95,0,2,110","dpcpus":"0-1 5-6","sfcpus":"0-1 5-6"}'
        simple_client = '{"fg":{"decision":[{"type":"game_switch_enable","value":"7","perf_value":"7","autoTouchRate":false}],"sf_tf":"1,35"},"bg":{"decision":[{"type":"game_switch_enable","value":"0"},{"type":"target_load_notification","value":"0"}],"sf_tf":"0,0"}}'
        game_zone = '{"delay_time":"1000","recognize_interval":"8000","wake_up_times":"10","key_thread_ux":"2","key_worker_ux":"2","white_list_ux":"2","white_list":["UnityPreload","Worker Thread","UnityChoreograp","NativeThread","UnityGfxDeviceW","UnityMain","Thread-","miHoYo.Yuanshen"],"bind_core":"1","search_white_list":"50","pipeline":{"7":"UnityGfxDeviceW","4":"UnityMain","3":"UnityMultiRende","-1":"UnityChoreograp"},"bind_list":{"Thread-":"g_2","Worker Thread": "g_2","UnityPreload": "g_5","NativeThread": "g_2","GameAssistant0":"g_2","UnityChoreograp":"g_6"}}'
        control = '{"yskeepalive":{"timeout":300,"framerate":5,"bindcore":true,"thermal":15,"virtualScreenRunningTime":20,"moveVDInterval":2}}'
        thermal_frame = '{"60":{"tt":470,"phase":2,"param":"5,48,10,49,30","mg":2}}'
        unity_game_boost = '{"60":{"start": 48,"target": 49,"minfps": 51,"charging":"-1,-5"}}'
        resv_8 = '{"edr3":"on","thermal":{"0":80},"solutions":["rcas","vrs"]}'
        resv_13 = '{"targetFrameInsertFPS":120,"maxLowFPS":24,"lowFPSLimit":30,"minLowFPS":10,"thermalLimit":47,"thermalLevelLimit":11,"validThermalLevel":8,"sr_hdr_normal":48,"sr_hdr_low":48,"sr_hdr_high":51,"sr_hdr_x":51,"resv":1101}'
        fps_stabilizer = '{"boostStep":"1.1,1.4","freqStep":"12,0,17,0,15,0,18,0,12,6,18,17,15,0,18,18","temp":450,"boostTime":"100"}'
        gov_preset_1()
    elseif (pkg == "com.tencent.tmgp.sgame" or pkg == "com.levelinfinite.sgameGlobal") then
        cpu_config = '{"loading":{"boost":"","time":5000}}'
        gpu_config = '{"470":{"c0":12,"c1":16,"c2":-1,"c3":13,"fps":-1}}'
        gpa_config = '{"30":{"cl":7,"ch":11,"sm":9,"gf":7,"gm":11,"tl":7,"th":10,"fast":"95,95,0,0,110"},"60":{"cl":-1,"ch":11,"sm":9,"gm":11,"tl":-1,"th":10,"fast":"100,95,0,0,105","pf":"4,0,3,2,2,0","pip":1,"dpcpus":"0-1 5-6","sfcpus":"0-1 5-6"},"90":{"cl":6,"ch":18,"sm":13,"gm":17,"th":14,"pip":1,"fw":0,"fast":"95,95,0,0,110","dpcpus":"0-1 5-6","sfcpus":"0-1 5-6"},"120":{"cl":12,"ch":18,"sm":13,"gm":21,"th":17,"pip":1,"fw":0,"fast":"95,95,0,2,110","dpcpus":"0-1 5-6","sfcpus":"0-1 5-6"}}'
        game_zone = '{"recognize_interval":"1000","wake_up_times":"10","key_thread_ux":"2","key_worker_ux":"2","white_list_ux":"2","white_list":["Worker Thread","NativeThread","CoreThread","tmgp.sgame","AILocalThread"],"pipeline":{"7":"UnityMain","4":"UnityGfx","3":"CoreThread"},"bind_list":{"CrashSightThrea":"g_1","UnityGfx":"g_2","Worker Thread":"g_2","NativeThread": "g_2","Thread-": "g_2","CoreThread":"g_2"},"system_process":["system_server"],"system_server":["InputReader","InputDispatcher"]}'
        thermal_frame = '{"120":{"tt":470,"phase":2,"param":"10,48,10,49,60","mgc":"30,50","mg":4},"90":{"tt":410,"phase":4,"param":"5,42,5,43,5,45,10,46,60","mgc":"30,47","mg":5},"60":{"tt":470,"phase":1,"param":"0,48,60","mg":0}}'
        resv_7 = '{"autoSystraceCollectEnabled":false,"latencyThreshold":23,"latencyIntervalThreshold":60000}'
        fps_stabilizer = '{"boostStep":"0.7,0.95","freqStep":"13,0,28,0,17,0,29,0,13,0,18,7,17,8,28,25","temp":450}'
        gov_preset_2()
    elseif (pkg == "com.kurogame.mingchao") then
        game_zone = '{"recognize_interval":"1000","wake_up_times":"10","key_thread_ux":"2","key_worker_ux":"2","white_list_ux":"2","white_list":["RHIThread","GameThread","RenderThread","Filter","TaskGraphHP","RTHeartBeat","rogame.mingchao","TaskGraphHP 0","TaskGraphHP 1","TaskGraphHP 2","TaskGraphHP 3","TaskGraphHP 4","TaskGraphHP 5","TaskGraphHP 6","TaskGraphHP 7","TaskGraphHP 8"],"search_white_list": 25,"pipeline": {"3":"RenderThread","4":"RHIThread","7":"GameThread"},"bind_list": {"Filter":"g_6"}}'
        set_offset(-1200000, -1400000, -300000, 0)
        gov_preset_1()
    elseif (pkg == "com.miHoYo.hkrpg" or pkg == "com.miHoYo.hkrpg.bilibili") then
        game_zone = '{"recognize_interval":"1000","wake_up_times":"10","key_thread_ux":"2","key_worker_ux":"2","white_list_ux":"2","white_list":["UnityPreload","Worker Thread","UnityChoreograp","NativeThread","UnityGfxDeviceW","UnityMain"],"bind_core":"1","pipeline":{"7":"UnityMain","4":"UnityGfxDeviceW"},"bind_list":{"UnityGfxDeviceW":"g_2"},"search_white_list":"50"}'
        fps_stabilizer = '{"boostStep":"1.1,2.0","freqStep":"12,0,15,12,5,0,9,9,12,0,15,15,5,0,13,13","temp":500}'
        set_offset(-1000000, 0, 0, 0)
        gov_preset_1()
    elseif (pkg == "com.hypergryph.exastris") then
        set_offset(-700000, -200000, -200000, 0)
        gov_preset_1()
    elseif (pkg == "com.dragonli.projectsnow.lhm") then
        game_zone = '{"recognize_interval":"1000","wake_up_times":"10","key_thread_ux":"2","key_worker_ux":"2","white_list_ux":"2","white_list":["RHIThread","GameThread","RenderThread"],"search_white_list": 25,"bind_extend": 3,"pipeline": {"7": "GameThread","4": "RHIThread","3": "RenderThread"},"bind_list": {"RHIThread":"g_5","RenderThread":"g_6","GameThread":"g_5"}}'
        set_offset(-200000, 0, -200000, 0)
        gov_preset_1()
    elseif (pkg == "com.miHoYo.Nap") then
        set_offset(-1200000, -1200000, -1200000, 0)
        gov_preset_1()
    elseif (pkg == "com.netease.l22" or pkg == "com.tencent.KiHan" or pkg == "com.tencent.tmgp.pubgmhd") then
        set_offset(0, 0, 0, 0)
        gov_preset_2()
    elseif (pkg == "com.tencent.nfsonline") then
        set_offset(-100000, 0, 0, 0)
        gov_preset_1()
    elseif (pkg == "com.tencent.KiHan") then
        set_offset(-200000, -200000, -200000, 0)
        gov_preset_2()
    elseif (pkg == "com.tencent.lolm") then
        set_offset(0, -200000, -200000, 0)
        gov_preset_2()
    else
        gov_preset_1()
    end
    cosa_surgery(pkg)
end

function target_fps_change(target_fps, pkg)
    if (pkg == "com.miHoYo.Yuanshen" or pkg == "com.miHoYo.ys.mi" or pkg == "com.miHoyo.ys.bilibili" or pkg == "com.miHoYo.GenshinImpact") then
        if target_fps == 60 or target_fps == 59 then
            set_offset(-300000, -300000, -300000, 0)
        elseif target_fps == 90 or target_fps == 89 then
            set_offset(-400000, 0, 0, 0)
        elseif target_fps == 120 or target_fps == 119 then
            set_offset(-600000, 0, 0, 0)
        end
    end
end

function unload_fas()
    set_offset(0, 0, 0, 0)
    set_governor("uag", "uag", "uag", "uag")
    gov_preset_0()
end