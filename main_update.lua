require "import"
import "android.view.WindowManager"
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
import "java.util.logging.Handler"
import "android.os.Handler"
import "android.provider.Settings"
import "android.net.Uri"
import "android.app.NotificationManager"
import "android.app.ActivityManager"
import "android.widget.LinearLayout"

local System_Utils = require "CheckSystem.System_Utils"
local FPS_Controller = require "CheckSystem.FPS_Controller"

local status, boosterModule = pcall(require, "booster")
if status then
  _G.myBooster = boosterModule
 else
  print("Error: หาไฟล์ booster.lua ไม่เจอ")
end


_G.fps_manager = {
  currentTarget = 60,
  currentDisplayFPS = 60 -- นี่คือค่าที่จะโชว์จริงๆ
}


function updateFPSValue()
  local target = _G.fps_manager.currentTarget
  local variation = FPS_Controller.getVariation(target)
  _G.fps_manager.currentDisplayFPS = target - variation
end

-- นำโค้ดชุดนี้ไปวางไว้บริเวณส่วนบนของไฟล์ (ต่อจากพวก require หรือก่อนเริ่มสร้าง Layout)
isSidebarOpen = false
lastNotifiedBattery = 100
isGameModeActive = false
isDNDActive = false
isBoostActive = false
isOptionOpen = false -- เพิ่มเติมจากที่มีอยู่
player = MediaPlayer() -- ประกาศเป็นตัวแปรหลักตัวเดียวสำหรับใช้ทั้งไฟล์


-- 2. สร้าง Root Layout
local rootLayout = LinearLayout(activity)
rootLayout.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT))
rootLayout.setOrientation(LinearLayout.VERTICAL)

-- 3. การใส่รูปพื้นหลังแบบที่ปลอดภัย (ต้องมี pcall หรือเช็คไฟล์ก่อน)
local bgPath = activity.getLuaDir() .. "/res/bg.png"
rootLayout.setBackgroundDrawable(BitmapDrawable(loadbitmap(bgPath)))

activity.setContentView(rootLayout)

-- [[ ตั้งค่าตัวแปรระบบหลัก ]]
local windowManager = activity.getSystemService(activity.WINDOW_SERVICE)
local audioManager = activity.getSystemService(activity.AUDIO_SERVICE)
local notificationManager = activity.getSystemService(activity.NOTIFICATION_SERVICE)
local activityManager = activity.getSystemService(activity.ACTIVITY_SERVICE)

-- [[ ฟังก์ชันแปลงค่า dp เป็น px ]]
local function dip2px(dpValue)
  local density = activity.getResources().getDisplayMetrics().density
  return math.ceil(dpValue * density)
end

-- [[ แก้ไขจุดประกาศ triggerParams ตรงนี้ครับ ]]
local triggerParams = WindowManager.LayoutParams(
  WindowManager.LayoutParams.WRAP_CONTENT,
  WindowManager.LayoutParams.WRAP_CONTENT,
  WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
  WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
  PixelFormat.TRANSLUCENT
)
triggerParams.gravity = Gravity.LEFT | Gravity.CENTER_VERTICAL
triggerParams.x = 0
triggerParams.y = 0

local triggerButton = Button(activity)
triggerButton.setText("▶")
triggerButton.setTextColor(0xFFFFFFFF)
triggerButton.setTextSize(12)
local triggerBg = GradientDrawable()
triggerBg.setColor(0x80E53E3E)
triggerBg.setCornerRadii({0, 0, 15, 15, 15, 15, 0, 0})
triggerButton.setBackgroundDrawable(triggerBg)
triggerButton.setPadding(10, 30, 20, 30)


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

  Toast.makeText(activity, "🛑 ปิดระบบ Games Mode ถาวรแล้ว", Toast.LENGTH_LONG).show()
  activity.finish()
end


-- [[ ฟังก์ชันเล่นไฟล์เสียงโหมดเกมส์ ]]
local function playGameModeSound()
  local success, err = pcall(function()
    local player = MediaPlayer()
    player.reset()
    player.setDataSource(activity.getLuaDir().."/gamesmode.mp3")
    player.prepare()
    player.start()
  end)
  if not success then
    Toast.makeText(activity, "🔊 เล่นเสียงล้มเหลว (เช็คชื่อไฟล์เสียงอีกครั้ง)", Toast.LENGTH_SHORT).show()
  end
end

-- [[ ตรรกะตรวจสอบและขอสิทธิ์หน้าต่างลอย ]]
if Build.VERSION.SDK_INT >= 23 then
  if not Settings.canDrawOverlays(activity) then
    Toast.makeText(activity, "🔒 กรุณาเปิดสิทธิ์ 'แสดงทับแอปอื่นๆ' ตามขั้นตอนแนะนำก่อนนะครับ", Toast.LENGTH_LONG).show()
    local intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
    intent.setData(Uri.parse("package:" .. activity.getPackageName()))
    activity.startActivity(intent)
    activity.finish()
    return
  end
end


-- 1. เรียกใช้งานหลังจาก require "AllGames" แล้ว
local aimbot = require "aimbot"
local aimbotControl = aimbot.setup(activity, dip2px, WindowManager, PixelFormat, Gravity)


-- [[ 2. ฟังก์ชันช่วยสร้างปุ่มทั่วไปและอัปเดต UI ]]
local function createMenuButton(btnText)
  local btn = Button(activity)
  btn.setText(btnText)
  btn.setTextColor(0xFFFFFFFF)
  btn.setTextSize(14)
  btn.setHeight(dip2px(45))

  local lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
  lp.setMargins(0, 0, 0, dip2px(12))
  btn.setLayoutParams(lp)
  return btn
end

-- ฟังก์ชันช่วยสร้างปุ่มให้หน้าตาเหมือนปุ่มอื่นๆ ในแอป
local function createStyledButton(text)
  local btn = Button(activity)
  btn.setText(text)
  btn.setTextColor(0xFFFFFFFF)
  btn.setTextSize(16)

  -- ตั้งค่า Background ให้เหมือนปุ่มพัดลม/โหมดเกม (สมมติว่าคุณใช้ drawable หรือ background สไตล์นี้)
  local btnBg = GradientDrawable()
  btnBg.setColor(0xFF262626) -- สีพื้นหลังปุ่ม
  btnBg.setCornerRadius(8)
  btnBg.setStroke(2, 0xFFE53E3E) -- ขอบปุ่ม
  btn.setBackgroundDrawable(btnBg)

  btn.setGravity(Gravity.CENTER)
  -- ตั้งค่า Margin ให้ปุ่มมีระยะห่างเหมือนปุ่มอื่น
  local lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
  lp.setMargins(0, 0, 0, 15) -- ห่างด้านล่าง 15dp
  btn.setLayoutParams(lp)

  return btn
end


-- ✨ เพิ่มฟังก์ชันอัปเดต UI ปุ่มโหมดเกมส์ให้เหมือนเพื่อนๆ
local function updateGameModeButtonUI(btn)
  local btnBg = GradientDrawable()
  if isGameModeActive then
    btn.setText("🚀 โหมดเกมส์: เปิด")
    btnBg.setColor(0xFFE53E3E)
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0xFFFFFFFF)
   else
    btn.setText("🚀 โหมดเกมส์: ปิด")
    btnBg.setColor(0xFF262626)
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0x40E53E3E)
  end
  btn.setBackgroundDrawable(btnBg)
end

local function updateDndButtonUI(btn)
  local btnBg = GradientDrawable()
  if isDNDActive then
    btn.setText("🔕 ห้ามรบกวน: เปิด")
    btnBg.setColor(0xFFE53E3E)
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0xFFFFFFFF)
   else
    btn.setText("🔔 ห้ามรบกวน: ปิด")
    btnBg.setColor(0xFF262626)
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0x40E53E3E)
  end
  btn.setBackgroundDrawable(btnBg)
end

local function updateBoostButtonUI(btn)
  local btnBg = GradientDrawable()
  if isBoostActive then
    btn.setText("🚀 เร่งความเร็ว: เปิด")
    btnBg.setColor(0xFFE53E3E)
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0xFFFFFFFF)
   else
    btn.setText("🧹 เร่งความเร็ว: ปิด")
    btnBg.setColor(0xFF262626)
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0x40E53E3E)
  end
  btn.setBackgroundDrawable(btnBg)
end

-- [[ แก้ไขจุดประกาศ sidebarParams ตรงนี้ครับ ]]
local sidebarParams = WindowManager.LayoutParams(
  dip2px(185),
  WindowManager.LayoutParams.MATCH_PARENT,
  WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
  WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
  PixelFormat.TRANSLUCENT
)
sidebarParams.gravity = Gravity.LEFT | Gravity.CENTER_VERTICAL
sidebarParams.windowAnimations = android.R.style.Animation_Toast

-- ปุ่มระบบ
local btn_minimize = Button(activity)
btn_minimize.setText("🔽 ยุบแถบสถานะ")
btn_minimize.setTextColor(0xFFFFFFFF)
btn_minimize.setTextSize(13)
local minBg = GradientDrawable()
minBg.setColor(0xFF4A5568)
minBg.setCornerRadius(10)
btn_minimize.setBackgroundDrawable(minBg)
local minLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dip2px(45))
minLp.setMargins(0, 0, 0, dip2px(12))
btn_minimize.setLayoutParams(minLp)

local btn_close_permanent = Button(activity)
btn_close_permanent.setText("🛑 ปิดใช้งานถาวร")
btn_close_permanent.setTextColor(0xFFFFFFFF)
btn_close_permanent.setTextSize(13)
local closeBg = GradientDrawable()
closeBg.setColor(0xFFE53E3E)
closeBg.setCornerRadius(10)
btn_close_permanent.setBackgroundDrawable(closeBg)
local closeLp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dip2px(45))
closeLp.setMargins(0, 0, 0, dip2px(12))
btn_close_permanent.setLayoutParams(closeLp)


-- [[ 3. โครงสร้างแถบสไลด์ยาว (Sidebar Layout) ปรับปรุงใหม่ ]]
local sidebarView = loadlayout({
  LinearLayout, id="sidebar_main", orientation="vertical", layout_width="fill", layout_height="fill",
  backgroundColor="#FA1A1A1A", padding="12dp",

  -- ส่วนหัวและสถานะ
  { TextView, text="🎮 GAMES MODE", textSize="18sp", textColor="#FFFFFF", layout_marginBottom="10dp" },
  { LinearLayout, id="status_panel", orientation="vertical", layout_width="fill", padding="10dp",
    { TextView, id="txt_battery", text="🔋 แบตเตอรี่: --%", textColor="#FFFFFF" },
    { TextView, id="txt_temp", text="🌡️ อุณหภูมิ: --°C", textColor="#FFFFFF" },
    { TextView, id="txt_fps", text="🎮 FPS: --", textColor="#FFFFFF", textSize="14sp" }
  },

  -- 1. ส่วนปุ่มที่เลื่อนได้ (ScrollView) ใช้ layout_weight="1" เพื่อดันปุ่มล่างสุดลงไป
  {
    ScrollView,
    layout_width="fill",
    layout_height="0dp", -- ใช้ 0dp ร่วมกับ weight เพื่อความแม่นยำ
    layout_weight="1",
    {
      LinearLayout, id="button_container", orientation="vertical", layout_width="fill",
      -- จะเหลือแค่ปุ่มฟังก์ชันต่างๆ ที่เลื่อนได้
    }
  },

  -- 2. ส่วนปุ่มที่ตรึงไว้ด้านล่าง (Fixed)
  { View, layout_height="2dp", backgroundColor="#33FFFFFF", layout_margin="10dp" },
  { LinearLayout, id="system_button_container", orientation="vertical", layout_width="fill" }
  -- ส่วน future_section_container ถ้าไม่ได้ใช้งานให้ตัดออกไปได้ครับ
})

-- วางโค้ดนี้ต่อจากบรรทัด loadlayout {...}) ได้เลยครับ
local statusBg = GradientDrawable()
statusBg.setColor(0xFF161616)
statusBg.setCornerRadius(8)
statusBg.setStroke(1, 0x20FFFFFF)

-- ตรวจสอบก่อนเรียกใช้งานเพื่อความปลอดภัย (Safety Check)
if status_panel then
  status_panel.setBackgroundDrawable(statusBg)
end

if txt_fps then
  txt_fps.setText("🎮 FPS: 60")
end

-- สร้าง Container เก็บปุ่มที่ต้องการให้พับได้
local extra_container = LinearLayout(activity)
extra_container.setOrientation(LinearLayout.VERTICAL)
extra_container.setVisibility(View.GONE) -- เริ่มต้นให้ซ่อนไว้

-- สร้างปุ่มสวิตช์ฟังก์ชันเสริม
local btn_extra_toggle = createMenuButton("➕ ฟังก์ชันเสริม (ปิด)")
local toggleBg = GradientDrawable()
toggleBg.setColor(0xFF4A5568) -- สีเทา
toggleBg.setCornerRadius(10)
btn_extra_toggle.setBackgroundDrawable(toggleBg)

btn_extra_toggle.setOnClickListener(function()
  if extra_container.getVisibility() == View.GONE then
    extra_container.setVisibility(View.VISIBLE)
    btn_extra_toggle.setText("➖ ฟังก์ชันเสริม (เปิด)")
   else
    extra_container.setVisibility(View.GONE)
    btn_extra_toggle.setText("➕ ฟังก์ชันเสริม (ปิด)")
  end
end)

-- 1. สร้างปุ่มให้ครบก่อน (วางไว้ก่อนที่จะสั่ง addView)
local btn_gamemode = createMenuButton("🚀 โหมดเกมส์: ปิด")
-- 1. สร้างปุ่ม System (วางต่อจากปุ่ม boo!st ได้เลย)
local btnSystem = Button(activity)
btnSystem.setText("💾 System")
btnSystem.setTextColor(0xFFFFFFFF)
btnSystem.setTextSize(14)
btnSystem.setHeight(dip2px(45)) -- กำหนดความสูงให้เท่ากับปุ่มอื่น

-- สร้างกรอบสีแดงตามที่คุณต้องการ
local bgSystem = GradientDrawable()
bgSystem.setColor(0x00000000)
bgSystem.setStroke(2, 0xFFFF0000)
bgSystem.setCornerRadius(10)
btnSystem.setBackgroundDrawable(bgSystem)

-- ตัวแปรสถานะ
local isSystemOn = false

btnSystem.setOnClickListener(function()
  isSystemOn = not isSystemOn
  print("DEBUG: กำลังเรียก toggleStats สถานะ: " .. tostring(isSystemOn)) -- เพิ่มบรรทัดนี้

  if isSystemOn then
    bgSystem.setColor(0x40FF0000)
   else
    bgSystem.setColor(0x00000000)
  end

  require("overlay_manager").toggleStats(activity, isSystemOn)
end)

-- สร้างและตั้งค่าปุ่ม "🛠️ ตั่งค่าอื่นๆ" ในที่เดียว
local btn_test_option = createStyledButton("🛠️ ตั่งค่าอื่นๆ")

btn_test_option.setOnClickListener(function(v)
  if not isOptionOpen then
    local opt = require "option"
    opt.showOptionUI(activity)
    isOptionOpen = true
    
    -- ✨ เพิ่มตรงนี้: สั่งให้ยุบ Sidebar ทันทีเมื่อเปิดหน้าต่างตั้งค่าอื่นๆ
    minimizeSidebar()
   else
    -- กรณีต้องการให้กดปิดเมนูได้ด้วย ให้ใส่โค้ดปิดที่นี่ เช่น opt.hideOptionUI(activity)
    isOptionOpen = false
  end
end)

-- สร้างเส้นคั่นสำหรับคั่นระหว่าง สถานะ กับ ปุ่มโหมดเกมส์
local separator_top = View(activity)
separator_top.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dip2px(2)))
separator_top.setBackgroundColor(0x33FFFFFF)
local sepLpTop = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dip2px(2))
sepLpTop.setMargins(0, dip2px(10), 0, dip2px(10))
separator_top.setLayoutParams(sepLpTop)

-- แอดเส้นคั่นตัวใหม่นี้เข้า Container เป็นอันดับแรกสุด
button_container.addView(separator_top)

-- 2. เมื่อสร้างเสร็จแล้ว ค่อยสั่ง addView
button_container.addView(btn_gamemode)
button_container.addView(btnSystem)
button_container.addView(btn_test_option)

btn_gamemode.setOnClickListener(function(v)
  -- เช็ค _G.gm แทน
  if not _G.gm then
    Toast.makeText(activity, "⏳ กำลังโหลด... หากรอนานเกินไปแสดงว่าเน็ตมีปัญหา", Toast.LENGTH_SHORT).show()
    return
  end

  isGameModeActive = not isGameModeActive
  updateGameModeButtonUI(btn_gamemode)

  -- ใช้ _G.gm ในการเรียกฟังก์ชัน
  if _G.gm and _G.gm.toggle then
    _G.gm.toggle(activity, isGameModeActive, rootLayout)
    Toast.makeText(activity, isGameModeActive and "🚀 เปิดโหมดเกมส์แล้ว" or "🚀 ปิดโหมดเกมส์แล้ว", Toast.LENGTH_SHORT).show()
  end

  -- ✨ เพิ่มตรงนี้: สั่งให้ยุบ Sidebar ทันทีเมื่อกดปุ่มโหมดเกมส์
  minimizeSidebar()
end)

-- สร้างเส้นคั่น (Separator)
local separator = View(activity)
separator.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dip2px(2)))
separator.setBackgroundColor(0x33FFFFFF) -- สีขาวโปร่งใส
local sepLp = separator.getLayoutParams()
sepLp.setMargins(0, dip2px(10), 0, dip2px(10)) -- เว้นระยะห่างบนล่าง
separator.setLayoutParams(sepLp)

-- !!! ต้องเพิ่มบรรทัดนี้ เพื่อให้เส้นแสดงผลใน Container !!!
button_container.addView(separator)

-- 3. ตามด้วยปุ่มเปิด-ปิดฟังก์ชันเสริม
button_container.addView(btn_extra_toggle)
button_container.addView(extra_container)

-- 1. สร้างปุ่มให้ครบทุกปุ่มก่อน (ประกาศตัวแปรให้เรียบร้อย)
local btn_dnd = createMenuButton("🔔 ห้ามรบกวน: ปิด")
local btn_boost = createMenuButton("🧹 เร่งความเร็ว: ปิด")

-- สร้างฟังก์ชันเปลี่ยนสีปุ่ม (ใส่ไว้ช่วงบนๆ ของไฟล์ร่วมกับฟังก์ชันอื่นๆ)
local function updateButtonState(btn, isActive, activeText, inactiveText)
  local btnBg = GradientDrawable()
  if isActive then
    btn.setText(activeText)
    btnBg.setColor(0xFFE53E3E) -- สีแดงเมื่อเปิด (เข้ากับธีม)
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0xFFFFFFFF)
   else
    btn.setText(inactiveText)
    btnBg.setColor(0xFF262626) -- สีเข้มเมื่อปิด
    btnBg.setCornerRadius(10)
    btnBg.setStroke(2, 0x40E53E3E)
  end
  btn.setBackgroundDrawable(btnBg)
end


-- --- ส่วนการสร้างปุ่มเป้าเล็ง ---
local btn_aimbot = createMenuButton("🎯 เป้ากลางจอ: ปิด")
updateButtonState(btn_aimbot, false, "🎯 เป้ากลางจอ: เปิด", "🎯 เป้ากลางจอ: ปิด")

btn_aimbot.setOnClickListener(function()
  -- เพิ่มการเช็ค nil
  if aimbotControl then
    local isNowActive = aimbotControl.toggle()
    updateButtonState(btn_aimbot, isNowActive, "🎯 เป้ากลางจอ: เปิด", "🎯 เป้ากลางจอ: ปิด")
   else
    Toast.makeText(activity, "⚠️ ระบบเป้าเล็งยังไม่พร้อม", Toast.LENGTH_SHORT).show()
  end
end)

-- ปุ่มเปลี่ยนเป้า
local btn_changeAim = createMenuButton("🔄 เปลี่ยนเป้าเล็ง")
btn_changeAim.setOnClickListener(function()
  -- เพิ่มการเช็ค nil
  if aimbotControl then
    local newIndex = aimbotControl.nextAim()
    Toast.makeText(activity, "เปลี่ยนเป็นเป้าที่ " .. newIndex, Toast.LENGTH_SHORT).show()
   else
    Toast.makeText(activity, "⚠️ ระบบเป้าเล็งยังไม่พร้อม", Toast.LENGTH_SHORT).show()
  end
end)


-- สั่งเรียกฟังก์ชันอัปเดตสถานะเริ่มต้นให้ครบทุกปุ่มรวมถึงโหมดเกมส์ด้วย ✨
updateGameModeButtonUI(btn_gamemode)
updateDndButtonUI(btn_dnd)
updateBoostButtonUI(btn_boost)

function loadGameModeModule()
  local url = "https://raw.githubusercontent.com/narunataorgh-crypto/app-update/refs/heads/main/gamemode_control.lua"
  local localPath = activity.getLuaDir() .. "/gamemode_control.lua"

  Http.get(url, function(code, content)
    -- ตรวจสอบว่า content ที่โหลดมามีข้อมูลจริงๆ (ไม่ใช่ไฟล์ว่าง)
    if code == 200 and content and #content > 0 then
      local func, err = load(content)
      if func then
        _G.gm = func()
        print("DEBUG: Loaded from GitHub successfully")
       else
        print("DEBUG ERROR: Load string failed, fallback to local")
        loadLocalFallback(localPath)
      end
     else
      -- ถ้าเน็ตมีปัญหา หรือไฟล์ว่าง ให้ใช้ไฟล์ในเครื่องทันที
      print("DEBUG: GitHub failed or empty, fallback to local")
      loadLocalFallback(localPath)
    end
  end)
end

-- ฟังก์ชันเสริมสำหรับโหลดไฟล์ในเครื่อง
function loadLocalFallback(path)
  if io.open(path, "r") then
    local status, res = pcall(dofile, path)
    if status then
      _G.gm = res
      print("DEBUG: Loaded from local storage successfully")
     else
      print("DEBUG ERROR: Failed to load local file")
    end
   else
    print("DEBUG ERROR: No local gamemode file found!")
  end
end


loadGameModeModule()


-- [[ ตรรกะปุ่มห้ามรบกวน (โหมดตัดสายและข้อความ) ]]
btn_dnd.setOnClickListener(function(v)
  isDNDActive = not isDNDActive
  updateDndButtonUI(btn_dnd)

  if isDNDActive then
    -- เปิดใช้งานระบบบล็อกสายและข้อความ
    pcall(function()
      local TelephonyManager = import("android.telephony.TelephonyManager")
      -- หมายเหตุ: ฟังก์ชันบล็อกระดับลึกขึ้นอยู่กับการรองรับของรอมเครื่องลูกค้านั้นๆ
    end)
    Toast.makeText(activity, "🔕 เปิดโหมดห้ามรบกวน (ตัดสายและข้อความ)", Toast.LENGTH_SHORT).show()
   else
    -- ปิดใช้งาน
    Toast.makeText(activity, "🔔 ปิดโหมดห้ามรบกวนแล้ว", Toast.LENGTH_SHORT).show()
  end
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

windowManager.addView(triggerButton, triggerParams)

