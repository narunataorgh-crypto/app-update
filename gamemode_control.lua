require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.*"
import "android.graphics.drawable.*"
import "android.content.pm.ActivityInfo"
import "android.util.TypedValue"
import "android.os.BatteryManager"
import "android.content.IntentFilter"
import "android.content.Intent"
import "android.os.Build"
import "android.app.AlertDialog"

local gamemode = {}

-- [[ 1. ฟังก์ชันเช็ค Emulator ]]
function startApp()
  local brand = Build.BRAND:lower()
  if brand:find("generic") or brand:find("google_sdk") or brand:find("nox") or brand:find("sdk") then
    AlertDialog.Builder(activity)
    .setTitle("❌ แจ้งเตือน")
    .setMessage("ไม่อนุญาตให้ใช้งานบน Emulator")
    .setCancelable(false)
    .setPositiveButton("ออก", function() activity.finish() end)
    .show()
    return false
  end
  return true
end

-- [[ 2. ข้อมูลเกม (แก้ไข Path ให้ถอยหลัง 1 ระดับด้วย ../) ]]
local gameList = {
  {
    name="GARENA ROV",
    color="#442233",
    tag1="Stable Ping",
    tag2="Ultra Graphics",
    path="../RoV/main.lua", -- ถอยหลังไปหาโฟลเดอร์ RoV
    image="../RoV/rov_picture.jpg" -- ถอยหลังไปหารูป rov_picture.jpg
  },
  {
    name="PUBG MOBILE",
    color="#223344",
    tag1="Esports Pro",
    tag2="90 FPS Support",
    path="../KPUBG/main.lua",
    image=nil
  },
  {
    name="FREE FIRE",
    color="#223344",
    tag1="Esports Pro",
    tag2="90 FPS Support",
    path="../freefire/main.lua",
    image=nil
  },
  {
    name="eFootball",
    color="#223344",
    tag1="Esports Pro",
    tag2="90 FPS Support",
    path="../eFootball/main.lua",
    image=nil
  },
}

local selectedGame = gameList[1]

function dip2px(dp)
  return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, activity.getResources().getDisplayMetrics())
end

function getSystemStats()
  local ifilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
  local batteryStatus = activity.registerReceiver(nil, ifilter)
  if batteryStatus then
    local level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
    local temp = batteryStatus.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) / 10
    return level, temp
  end
  return 0, 0
end

-- [[ 3. เริ่มทำงาน ]]
if startApp() then

  local layout = {
    RelativeLayout,
    layout_width="fill",
    layout_height="fill",
    backgroundColor="#FF080A1A",
    {LinearLayout,
      layout_width="fill",
      layout_height="60dp",
      gravity="center",
      padding="10dp",
      {LinearLayout, id="statBox1", layout_width="85dp", layout_height="40dp", gravity="center", layout_margin="5dp",
        {TextView, id="txt_fps", text="60 FPS", textColor="#00FFFF", textSize="10sp"}},
      {LinearLayout, id="statBox2", layout_width="85dp", layout_height="40dp", gravity="center", layout_margin="5dp",
        {TextView, id="txt_temp", text="--°C", textColor="#FFCC00", textSize="10sp"}},
      {LinearLayout, id="statBox3", layout_width="85dp", layout_height="40dp", gravity="center", layout_margin="5dp",
        {TextView, id="txt_batt", text="--%", textColor="#00FF00", textSize="10sp"}},
    },
    {HorizontalScrollView,
      id="gameScroll",
      layout_width="fill",
      layout_height="280dp",
      layout_marginTop="80dp",
      fillViewport=true,
      {LinearLayout,
        id="gameContainer",
        orientation="horizontal",
        layout_width="wrap",
        layout_height="fill",
        paddingLeft="50dp",
        paddingRight="50dp",
      }
    },
    {Button,
      id="btnStart",
      text="START "..selectedGame.name,
      layout_width="220dp",
      layout_height="65dp",
      layout_centerHorizontal=true,
      layout_alignParentBottom=true,
      layout_marginBottom="30dp",
      textColor="#FFFFFF",
      textSize="16sp",
    }
  }

  activity.setContentView(loadlayout(layout))
  activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
  gameScroll.setHorizontalScrollBarEnabled(false)

  local function createCardShape(color)
    local gd = GradientDrawable()
    gd.setColor(Color.parseColor(color))
    gd.setCornerRadius(dip2px(20))
    return gd
  end

  -- [[ 4. วนลูปสร้างการ์ด ]]
  for i, game in ipairs(gameList) do
    local cardLayout = {
      LinearLayout,
      layout_width="350dp",
      layout_height="fill",
      layout_margins="15dp", -- เติม s เรียบร้อย
      {RelativeLayout,
        layout_width="fill",
        layout_height="fill",
        {ImageView,
          layout_width="fill",
          layout_height="fill",
          scaleType="centerCrop",
          -- แก้ไข: เชื่อม Path ให้ถอยหลังออกไปหาโฟลเดอร์ข้างนอก
          src=(game.image and activity.getLuaDir().."/"..game.image or nil),
        },
        {LinearLayout,
          layout_width="fill",
          layout_height="100dp",
          layout_alignParentBottom=true,
          backgroundColor="#CC000000",
          orientation="vertical",
          padding="15dp",
          {TextView, text=game.name, textColor="#FFFFFF", textSize="18sp"},
          {LinearLayout, layout_width="wrap", layout_height="wrap", layout_marginTop="5dp",
            {TextView, text=" "..game.tag1.." ", backgroundColor="#3300FFFF", textColor="#00FFFF", textSize="8sp", layout_marginRight="8dp"},
            {TextView, text=" "..game.tag2.." ", backgroundColor="#33FFCC00", textColor="#FFCC00", textSize="8sp"},
          },
        },
      },
    }

    local card = loadlayout(cardLayout)

    -- เช็คไฟล์ภาพ
    local hasImage = false
    if game.image then
      local fullPath = activity.getLuaDir().."/"..game.image
      local f = io.open(fullPath, "r")
      if f then
        hasImage = true
        io.close(f)
      end
    end

    if not hasImage then
      card.setBackgroundDrawable(createCardShape(game.color))
    end

    card.onClick = function()
      selectedGame = game
      btnStart.setText("START "..game.name)
      Toast.makeText(activity, "เลือก: "..game.name, 0).show()
    end

    gameContainer.addView(card)
  end

  -- ตกแต่งปุ่ม
  local function setModernBox(view, color)
    local gd = GradientDrawable()
    gd.setColor(0x33000000)
    gd.setCornerRadius(dip2px(12))
    gd.setStroke(dip2px(1), Color.parseColor(color))
    view.setBackgroundDrawable(gd)
  end
  setModernBox(statBox1, "#00FFFF")
  setModernBox(statBox2, "#FFCC00")
  setModernBox(statBox3, "#00FF00")

  local startShape = GradientDrawable()
  startShape.setCornerRadius(dip2px(32))
  startShape.setColors({0xFF4488FF, 0xFF0044CC})
  btnStart.setBackgroundDrawable(startShape)

  -- [[ ส่วนนี้คือจุดสิ้นสุดของโครงสร้างหลักที่เจมส์รันได้ปกติ ]]
  local timer = Ticker()
  timer.Period = 2000
  timer.onTick = function()
    pcall(function()
      local batt, temp = getSystemStats()
      txt_batt.setText(batt.."%")
      txt_temp.setText(temp.."°C")
    end)
  end
  timer.start()

  -- [[ จุดจำลองการเชื่อมต่อ: เมื่อกดปุ่ม START ]]
  btnStart.onClick = function()
    -- จำลองว่าไฟล์ pin.lua อยู่ที่นี่
    local pinPath = activity.getLuaDir().."/pin.lua"

    if io.open(pinPath, "r") then
      -- แสดงสถานะการเชื่อมต่อจำลอง
      Toast.makeText(activity, "🔄 กำลังเชื่อมต่อเมนูโปร...", 0).show()

      -- คำสั่งเด้งไปหน้าเมนูโปร (pin.lua)
      dofile(pinPath)
     else
      -- ถ้ายังไม่มีไฟล์ pin.lua ให้แสดงข้อความเตือนตำแหน่งไฟล์
      Toast.makeText(activity, "⚠️ จำลอง: ระบบหา pin.lua ไม่เจอในโฟลเดอร์หลัก", 1).show()
    end
  end
end -- ปิดบล็อก if startApp()


return gamemode
