-- ==========================================
-- SECTION 1: IMPORTS & INITIALIZATION
-- ==========================================
require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.PixelFormat"
import "android.graphics.drawable.GradientDrawable"
import "android.graphics.Typeface"
import "android.media.MediaPlayer"
import "android.content.Context"
import "android.content.Intent"
import "android.content.IntentFilter"
import "android.graphics.drawable.BitmapDrawable"
import "android.os.BatteryManager"
import "android.media.AudioManager"
import "android.os.Build"
import "android.os.Handler"
import "android.provider.Settings"
import "android.net.Uri"
import "android.app.NotificationManager"
import "android.app.ActivityManager"

local System_Utils = require "CheckSystem.System_Utils"
local FPS_Controller = require "CheckSystem.FPS_Controller"

local status, boosterModule = pcall(require, "booster")
if status then _G.myBooster = boosterModule end

_G.fps_manager = {currentTarget = 60, currentDisplayFPS = 60}
function updateFPSValue()
  local target = _G.fps_manager.currentTarget
  local variation = FPS_Controller.getVariation(target)
  _G.fps_manager.currentDisplayFPS = target - variation
end

-- ==========================================
-- SECTION 2: FUNCTIONS & HELPERS
-- ==========================================
local function dip2px(dpValue) return math.ceil(dpValue * activity.getResources().getDisplayMetrics().density) end

local function createMenuButton(btnText)
  local btn = Button(activity)
  btn.setText(btnText)
  btn.setTextColor(0xFFFFFFFF)
  btn.setTextSize(14)
  btn.setHeight(dip2px(45))
  local lp = LinearLayout.LayoutParams(-1, -2)
  lp.setMargins(0, 0, 0, dip2px(12))
  btn.setLayoutParams(lp)
  return btn
end

local function updateButtonState(btn, isActive, activeText, inactiveText)
  local btnBg = GradientDrawable()
  if isActive then
    btn.setText(activeText); btnBg.setColor(0xFFE53E3E); btnBg.setCornerRadius(10); btnBg.setStroke(2, 0xFFFFFFFF)
   else
    btn.setText(inactiveText); btnBg.setColor(0xFF262626); btnBg.setCornerRadius(10); btnBg.setStroke(2, 0x40E53E3E)
  end
  btn.setBackgroundDrawable(btnBg)
end

-- ==========================================
-- SECTION 3: UI LAYOUT
-- ==========================================
local player = MediaPlayer()
local isSidebarOpen, isGameModeActive, isDNDActive, isBoostActive, isOptionOpen = false, false, false, false, false
local lastNotifiedBattery = 100

local sidebarView = loadlayout({
  LinearLayout, id="sidebar_main", orientation="vertical", width="fill", height="fill",
  backgroundColor="#FA1A1A1A", padding="12dp",
  { TextView, text="🎮 GAMES MODE", textSize="18sp", textColor="#FFFFFF", layout_marginBottom="10dp" },
  { LinearLayout, id="status_panel", orientation="vertical", width="fill", padding="10dp",
    { TextView, id="txt_battery", text="🔋 แบตเตอรี่: --%", textColor="#FFFFFF" },
    { TextView, id="txt_temp", text="🌡️ อุณหภูมิ: --°C", textColor="#FFFFFF" },
    { TextView, id="txt_fps", text="🎮 FPS: --", textColor="#FFFFFF" }
  },
  { ScrollView, width="fill", height="0dp", layout_weight="1",
    { LinearLayout, id="button_container", orientation="vertical", width="fill" }
  },
  { View, height="2dp", backgroundColor="#33FFFFFF", layout_margin="10dp" },
  { LinearLayout, id="system_button_container", orientation="vertical", width="fill" }
})

-- ==========================================
-- SECTION 4: LOGIC & BUTTON SETUP
-- ==========================================

-- 1. ประกาศตัวแปร Global/Local ที่จำเป็นต้องใช้
local audioManager = activity.getSystemService(Context.AUDIO_SERVICE)
local activityManager = activity.getSystemService(Context.ACTIVITY_SERVICE)

-- 2. สร้างปุ่มต่างๆ ที่ต้องใช้ใน Logic
local btn_dnd = createMenuButton("🔕 ห้ามรบกวน (ปิด)")
local btn_boost = createMenuButton("🚀 เคลียร์แรม")
local btn_aimbot = createMenuButton("🎯 Aimbot (ปิด)")
local btn_changeAim = createMenuButton("⚙️ ตั้งค่าเป้า")
local btn_minimize = createMenuButton("🔽 ยุบเมนู")
local btn_close_permanent = createMenuButton("❌ ปิดถาวร")

-- 3. ฟังก์ชันอัปเดต UI ปุ่มที่เหลือ (ถ้ายังไม่มี ให้ใส่ฟังก์ชันนี้ไว้ใน SECTION 2)
function updateDndButtonUI(btn)
  updateButtonState(btn, isDNDActive, "🔕 ห้ามรบกวน (เปิด)", "🔕 ห้ามรบกวน (ปิด)")
end
function updateBoostButtonUI(btn)
  updateButtonState(btn, isBoostActive, "🚀 กำลังเร่งความเร็ว...", "🚀 เคลียร์แรม")
end

-- ต่อด้วยส่วนเดิมของคุณ:
local button_container = sidebarView.getChildAt(2).getChildAt(0)
local system_button_container = sidebarView.getChildAt(4)
-- (แล้วตามด้วยคำสั่งสร้างปุ่มและตรรกะเดิมของคุณ...)

-- สร้างปุ่มต่างๆ
local btn_gamemode = createMenuButton("🚀 โหมดเกมส์: ปิด")
local btnSystem = createMenuButton("💾 System")
local btn_test_option = createMenuButton("🛠️ ตั่งค่าอื่นๆ")
local btn_extra_toggle = createMenuButton("➕ ฟังก์ชันเสริม (ปิด)")
local extra_container = LinearLayout(activity); extra_container.setOrientation(1); extra_container.setVisibility(8)

-- Logic ต่างๆ (ใส่ Logic เดิมของคุณที่นี่)
local gm = require "gamemode_control"
btn_gamemode.setOnClickListener(function()
  isGameModeActive = not isGameModeActive
  gm.toggle(activity, isGameModeActive, nil)
  updateButtonState(btn_gamemode, isGameModeActive, "🚀 โหมดเกมส์: เปิด", "🚀 โหมดเกมส์: ปิด")
end)

-- (ต่อด้วยการ addView ปุ่มทั้งหมดเข้า container เหมือนโค้ดเดิมของคุณ)
button_container.addView(btn_gamemode)
button_container.addView(btnSystem)
button_container.addView(btn_test_option)
button_container.addView(btn_extra_toggle)
button_container.addView(extra_container)

-- [ ส่วนระบบอื่นๆ เช่น music, macro, aimbot ให้เรียกใช้ที่นี่ได้เลย ]
-- ตัวอย่าง: extra_container.addView(ปุ่มต่างๆ...)
-- [[ ตรรกะปุ่มห้ามรบกวน (นำโค้ดไปวางแทนของเดิมในส่วนนี้) ]]
btn_dnd.setOnClickListener(function(v)
  -- 1. ตรวจสอบสิทธิ์ก่อนทำงาน
  if Build.VERSION.SDK_INT >= 23 then
    local nm = activity.getSystemService(Context.NOTIFICATION_SERVICE)
    if not nm.isNotificationPolicyAccessGranted() then
      Toast.makeText(activity, "🔒 กรุณาอนุญาตสิทธิ์ 'ห้ามรบกวน' ให้แอปก่อนนะครับ", Toast.LENGTH_LONG).show()
      activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
      return -- หยุดการทำงานไว้แค่นี้จนกว่าจะกดอนุญาต
    end
  end

  -- 2. ถ้ามีสิทธิ์แล้ว ค่อยทำงานตามตรรกะเดิมของคุณ
  if not isDNDActive then
    audioManager.setRingerMode(AudioManager.RINGER_MODE_VIBRATE)
    isDNDActive = true
    Toast.makeText(activity, "🔕 เปิดโหมดเงียบเสียง (สั่น)", Toast.LENGTH_SHORT).show()
   else
    audioManager.setRingerMode(AudioManager.RINGER_MODE_NORMAL)
    isDNDActive = false
    Toast.makeText(activity, "🔔 ปิดโหมดเงียบเสียง", Toast.LENGTH_SHORT).show()
  end

  -- 3. อัปเดต UI ปุ่ม
  updateDndButtonUI(btn_dnd)
end)

btn_boost.setOnClickListener(function(v)
  if not isBoostActive then
    isBoostActive = true
    updateBoostButtonUI(btn_boost)

    -- เรียกใช้ผ่าน _G.myBooster ที่เราโหลดไว้แล้ว
    if _G.myBooster then
      local freedMemory = _G.myBooster.execute(activity, activityManager)
      Toast.makeText(activity, string.format("🚀 เปิดโหมดเร่งความเร็ว! คืนพื้นที่ได้ %d MB", freedMemory), Toast.LENGTH_LONG).show()
     else
      Toast.makeText(activity, "❌ ไม่พบโมดูลเร่งความเร็ว", Toast.LENGTH_SHORT).show()
      isBoostActive = false
      updateBoostButtonUI(btn_boost)
    end

   else
    isBoostActive = false
    updateBoostButtonUI(btn_boost)
    Toast.makeText(activity, "🧹 ปิดโหมดเร่งความเร็วแล้ว", Toast.LENGTH_SHORT).show()
  end
end)



-- 2. ใส่ Margin ให้ปุ่ม (เพื่อให้ระยะห่างเท่ากับปุ่มอื่น)
local lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
lp.setMargins(0, 0, 0, dip2px(12))
btnSystem.setLayoutParams(lp)

-- 1. เรียกใช้งานและรับค่าปุ่มที่ส่งกลับมา
local fan_module = require "fan_refresh"
local btns = fan_module.setup(activity, dip2px, createMenuButton, button_container)
local btn_refresh = btns.btn_refresh -- ดึงปุ่มรีเฟรชออกมาจัดการ

-- 2. เมื่อสร้างเสร็จแล้ว ค่อยสั่ง addView
extra_container.addView(btn_dnd)
extra_container.addView(btn_boost)
extra_container.addView(btn_refresh)
extra_container.addView(btn_aimbot)
extra_container.addView(btn_changeAim)

-- 1. ฟังก์ชันสแกนหาโฟลเดอร์ Music อัตโนมัติ
local musicList = {}
local function scanMusicFolders()
  musicList = {}
  local roots = {"/sdcard/", "/storage/"} -- ค้นหาในทั้งสองแหล่ง
  for _, root in ipairs(roots) do
    local cmd = "find " .. root .. " -type d -name 'Music' 2>/dev/null"
    local f = io.popen(cmd)
    for folder in f:lines() do
      local files = io.popen("ls " .. folder .. "/*.mp3 2>/dev/null")
      for file in files:lines() do
        table.insert(musicList, file)
      end
      files:close()
    end
    f:close()
  end
  table.sort(musicList) -- เรียง A-Z / ก-ฮ
end

-- 2. สร้าง UI กรอบสีเขียวโปร่งแสง
local musicPanel = LinearLayout(activity)
musicPanel.setOrientation(LinearLayout.VERTICAL)
local panelBg = GradientDrawable()
panelBg.setColor(0x4000FF00)
panelBg.setStroke(2, 0xFF00FF00)
panelBg.setCornerRadius(10)
musicPanel.setBackgroundDrawable(panelBg)
musicPanel.setPadding(dip2px(10), dip2px(10), dip2px(10), dip2px(10))

-- 3. ส่วนหัวและปุ่ม (ใช้ Horizontal Layout)
local headerLayout = LinearLayout(activity)
headerLayout.setOrientation(LinearLayout.HORIZONTAL) -- จัดแนวนอน
headerLayout.setGravity(Gravity.CENTER_VERTICAL)

local tv_music = TextView(activity)
tv_music.setText("🎧 เพลงโปรดของคุณ")
tv_music.setTextColor(0xFFFFFFFF)
tv_music.setTextSize(12)
local lp_tv = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
tv_music.setLayoutParams(lp_tv)
headerLayout.addView(tv_music)

-- ปุ่ม ⏯
local btn_music_control = Button(activity)
btn_music_control.setText("⏯")
btn_music_control.setTextSize(12)
btn_music_control.setTextColor(0xFFFFFFFF)
local btnParams = LinearLayout.LayoutParams(dip2px(35), dip2px(35))
btn_music_control.setLayoutParams(btnParams)
local btnControlBg = GradientDrawable()
btnControlBg.setColor(0xFF4A5568)
btnControlBg.setCornerRadius(8)
btn_music_control.setBackgroundDrawable(btnControlBg)
headerLayout.addView(btn_music_control)

musicPanel.addView(headerLayout) -- แอด header เข้า panel

-- 4. ส่วนแสดงผลสถานะ (แอดเพิ่มต่อจาก header)
local txt_status = TextView(activity)
txt_status.setTextColor(0xFFFFFFFF)
txt_status.setTextSize(11)
txt_status.setPadding(0, dip2px(5), 0, 0)
musicPanel.addView(txt_status)

button_container.addView(musicPanel) -- แอด panel เข้า container หลัก

-- 5. ตรรกะการทำงาน
local totalTimeSeconds = 0
local startTime = 0
-- ตัวแปรสถานะสำหรับการเล่นเพลง
local isPlaying = false

-- เปลี่ยนจาก setOnCheckedChangeListener เป็น setOnClickListener
btn_music_control.setOnClickListener(function(v)
  isPlaying = not isPlaying

  if isPlaying then
    -- เปลี่ยนสีปุ่มเป็นสีฟ้าเมื่อกดเล่น
    btnControlBg.setColor(0xFF2196F3)
    btn_music_control.setBackgroundDrawable(btnControlBg)

    -- สแกนและเล่นเพลง
    Thread(function()
      scanMusicFolders()
      if #musicList > 0 then
        pcall(function()
          player.reset()
          player.setDataSource(musicList[1])
          player.prepare()
          player.start()
        end)

        activity.runOnUiThread(function()
          startTime = os.time()
          txt_status.setText(string.format("กำลังเล่น: %s", musicList[1]:match("([^/]+)$")))
        end)
      end
    end).start()

   else
    -- เปลี่ยนสีปุ่มเป็นสีเทาเมื่อหยุด
    btnControlBg.setColor(0xFF4A5568)
    btn_music_control.setBackgroundDrawable(btnControlBg)

    -- หยุดเล่นเพลง
    if player.isPlaying() then
      player.stop()
    end

    local endTime = os.time()
    totalTimeSeconds = totalTimeSeconds + (endTime - startTime)

    local h = math.floor(totalTimeSeconds / 3600)
    local m = math.floor((totalTimeSeconds % 3600) / 60)
    local s = totalTimeSeconds % 60
    txt_status.setText(string.format("จำนวน: %d เพลง\nสถานะ: หยุดพัก\nฟังไปแล้ว: %02d:%02d:%02d", #musicList, h, m, s))
  end
end)

local Check_System = require "CheckSystem.Check_System"
local status, message = Check_System.verifyDevice()

-- แสดงข้อความเตือนเสมอ
Toast.makeText(activity, message, Toast.LENGTH_LONG).show()

-- จัดการปุ่มตามสถานะ
if status == "supported" then
  -- เครื่องรองรับ: ปุ่มกดได้ปกติ (ไม่ต้องทำอะไร)
  btn_refresh.setEnabled(true)
  btn_refresh.setAlpha(1.0)

 elseif status == "warning" then
  -- เครื่อง z2467: ปุ่มกดได้ปกติ + โชว์ข้อความเตือนแล้ว
  btn_refresh.setEnabled(true)
  btn_refresh.setAlpha(1.0)

 else -- status == "unsupported"
  -- เครื่องไม่รองรับอื่นๆ: ล็อกปุ่ม
  btn_refresh.setEnabled(false)
  btn_refresh.setAlpha(0.3)
  btn_refresh.setOnClickListener(function()
    Toast.makeText(activity, "เครื่องไม่รองรับการปรับรีเฟรชเรท", Toast.LENGTH_SHORT).show()
  end)
end

-- 1. เรียกใช้งานหลังจาก require "AllGames" แล้ว
local aimbot = require "aimbot"
local aimbotControl = aimbot.setup(activity, dip2px, WindowManager, PixelFormat, Gravity)



local macro = require "macro"
-- ตรวจสอบว่า macro โหลดสำเร็จ
if macro then
  local macroControl = macro.setup(activity, dip2px, WindowManager, PixelFormat, Gravity, View, LinearLayout, TextView, Button, Toast)

  if macroControl then
    local btn_macro = createMenuButton("🤖 ตั้งค่ามาโคร")
    btn_macro.setOnClickListener(function()
      macroControl.togglePanel()
    end)
    extra_container.addView(btn_macro) -- คุณต้องมั่นใจว่าแอดปุ่มนี้เข้า extra_container
  end
end


-- แอดปุ่มระบบเข้ากล่องควบคุม
system_button_container.addView(btn_minimize)
system_button_container.addView(btn_close_permanent)


-- [[ 5. ตรรกะดึงข้อมูลแบตเตอรี่ ]]
local batteryReceiver = LuaBroadcastReceiver(function(context, intent)
  local level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
  local scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
  local batteryPct = math.floor((level / scale) * 100)

  local rawTemp = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
  local tempC = System_Utils.getCPUTemp()

  txt_battery.setText(string.format("🔋 แบตเตอรี่: %d%%", batteryPct))
  txt_temp.setText(string.format("🌡️ อุณหภูมิ: %d°C", tempC)) -- เปลี่ยนเป็น %d เพราะเราปัดเศษแล้ว

  if batteryPct < 80 then
    if lastNotifiedBattery == 100 or (lastNotifiedBattery - batteryPct) >= 5 then
      lastNotifiedBattery = batteryPct
      Toast.makeText(activity, string.format("⚠️ แจ้งเตือน! แบตเตอรี่เหลือต่ำกว่า %d%%", batteryPct), Toast.LENGTH_LONG).show()
    end
   else
    lastNotifiedBattery = 100
  end
end)

activity.registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
local sidebarParams = WindowManager.LayoutParams(-1, -1, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, 8, -3)

-- [[ 6. ตรรกะจัดการระบบ เปิด - ยุบ - ปิดถาวร ]]
local function openSidebar()
  if not isSidebarOpen then
    windowManager.addView(sidebarView, sidebarParams)
    windowManager.removeView(triggerButton)
    isSidebarOpen = true
  end
end

local function minimizeSidebar()
  if isSidebarOpen then
    windowManager.removeView(sidebarView)
    windowManager.addView(triggerButton, triggerParams)
    isSidebarOpen = false
  end
end

local function closePermanent()
  if isSidebarOpen then
    windowManager.removeView(sidebarView)
   else
    pcall(function() windowManager.removeView(triggerButton) end)
  end
  isSidebarOpen = false
  pcall(function() activity.unregisterReceiver(batteryReceiver) end)

  if isDNDActive then
    pcall(function() audioManager.setRingerMode(AudioManager.RINGER_MODE_NORMAL) end)
  end

  Toast.makeText(activity, "🛑 ปิดระบบ Games Mode ถาวรแล้ว", Toast.LENGTH_LONG).show()
  activity.finish()
end

-- ใน main.lua
local function startFakeFPSCounter()
  local handler = Handler()
  local runnable
  -- ใน main.lua ฟังก์ชัน startFakeFPSCounter
  runnable = Runnable({
    run = function()
      if isSidebarOpen then
        updateFPSValue() -- สั่งสุ่มเลขใหม่ที่นี่ก่อนโชว์
        if txt_fps then
          txt_fps.setText("🎮 FPS: " .. _G.fps_manager.currentDisplayFPS)
        end
      end
      handler.postDelayed(runnable, 2000)
    end
  })
  handler.post(runnable)
end

-- เรียกฟังก์ชันนี้หลังจาก setup ทุกอย่างเสร็จแล้ว
startFakeFPSCounter()

triggerButton.setOnClickListener(function(v) openSidebar() end)
btn_minimize.setOnClickListener(function(v) minimizeSidebar() end)
btn_close_permanent.setOnClickListener(function(v) closePermanent() end)

-- ==========================================
-- SECTION 5: SYSTEM & OVERLAY
-- ==========================================
local windowManager = activity.getSystemService(Context.WINDOW_SERVICE)
local triggerParams = WindowManager.LayoutParams(-2, -2, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, 8, -3)
triggerParams.gravity = 3 | 16

local triggerButton = Button(activity)
triggerButton.setText("▶")

-- ใช้ฟังก์ชัน openSidebar ที่เราประกาศไว้ใน SECTION 4 แทน[span_1](start_span)[span_1](end_span)
triggerButton.setOnClickListener(function()
  openSidebar() 
end)

windowManager.addView(triggerButton, triggerParams)
