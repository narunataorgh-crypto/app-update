require "import"
import "android.widget.*"
import "android.view.*"
import "android.graphics.*"
import "android.media.*"
import "android.graphics.drawable.*"
import "android.content.Intent"
import "android.net.Uri"
import "android.content.pm.ApplicationInfo"
import "android.widget.GridLayout"
import "com.androlua.Http"

-- ประกาศที่ส่วนบนของไฟล์
local manualContainer

local gamemode = {}

local function loadManualGames(activity)
  if not manualContainer then return end

  manualContainer.removeAllViews()
  local filePath = activity.getLuaDir() .. "/saved_games.txt"
  local pm = activity.getPackageManager()
  local lines = {}

  -- อ่านไฟล์
  local f = io.open(filePath, "r")
  if f then
    for line in f:lines() do
      if line:gsub("%s+", "") ~= "" then table.insert(lines, line) end
    end
    f:close()
  end

  local function createItem(pkg, index)
    local info = pm.getApplicationInfo(pkg, 0)

    local itemLayout = LinearLayout(activity)
    itemLayout.setOrientation(LinearLayout.VERTICAL)
    itemLayout.setGravity(Gravity.CENTER)
    itemLayout.setPadding(2, 2, 2, 2)

    -- คำนวณความกว้างใหม่: เอาความกว้างหน้าจอ หาร 4 แล้วลบ Padding ออกเล็กน้อย
    local screenWidth = activity.getWindowManager().getDefaultDisplay().getWidth()
    local itemWidth = (screenWidth - 100) / 4 -- ลบ 100 คือเผื่อระยะขอบ padding ของหน้าหลัก

    local params = GridLayout.LayoutParams()
    params.width = itemWidth
    params.height = 160 -- ปรับขึ้นมานิดหน่อยให้ไม่เบียด
    itemLayout.setLayoutParams(params)

    -- เปลี่ยนจาก Button เป็น ImageView เพื่อโชว์แค่ไอคอน
    local iconView = ImageView(activity)
    local icon = pm.getApplicationIcon(info)
    iconView.setImageDrawable(icon)
    local iconParams = LinearLayout.LayoutParams(90, 90) -- ปรับเป็น 90x90
    iconView.setLayoutParams(iconParams)


    -- ทำการคลิกที่ ImageView ได้โดยตรง
    iconView.setOnClickListener(function()
      local intent = pm.getLaunchIntentForPackage(pkg)
      if intent then activity.startActivity(intent) end
    end)

    -- ทำการ LongClick ที่ ImageView
    iconView.setOnLongClickListener(View.OnLongClickListener({
      onLongClick = function(v)
        import "android.app.AlertDialog"
        AlertDialog.Builder(activity)
        .setTitle("ลบแอป")
        .setMessage("นำ " .. tostring(pm.getApplicationLabel(info)) .. " ออก?")
        .setPositiveButton("ลบ", function()
          table.remove(lines, index)
          local fw = io.open(filePath, "w")
          if fw then
            for _, p in ipairs(lines) do fw:write(p .. "\n") end
            fw:close()
          end
          loadManualGames(activity)
        end)
        .setNegativeButton("ยกเลิก", nil).show()
        return true
      end
    }))

    -- สร้าง TextView สำหรับชื่อแอป
    local label = TextView(activity)
    label.setText(tostring(pm.getApplicationLabel(info)))
    label.setTextColor(0xFFFFFFFF)
    label.setTextSize(10)
    label.setGravity(Gravity.CENTER)
    -- ปรับระยะห่างให้ชิดไอคอน (ใช้ค่าติดลบให้น้อยลงได้ตามต้องการ)
    label.setPadding(0, 0, 0, 0)

    -- เพิ่ม ImageView และ TextView เข้าไปใน itemLayout
    itemLayout.addView(iconView)
    itemLayout.addView(label)

    manualContainer.addView(itemLayout)
  end

  -- วนลูปสร้างไอคอน
  for i, pkg in ipairs(lines) do
    local success, info = pcall(function() return pm.getApplicationInfo(pkg, 0) end)
    if success and info then
      createItem(pkg, i)
    end
  end

  -- สร้างปุ่ม "+" (อยู่ข้างนอก loop และข้างนอก createItem)
  local addBtn = Button(activity)
  local params = GridLayout.LayoutParams()
  params.width = 100
  params.height = 100
  params.setGravity(Gravity.CENTER)
  addBtn.setLayoutParams(params)

  local imgPath = activity.getLuaDir() .. "/res/button_pass.png"
  if io.open(imgPath, "r") then
    io.close()
    addBtn.setBackgroundDrawable(BitmapDrawable(activity.getResources(), imgPath))
   else
    addBtn.setText("➕")
  end

  addBtn.setOnClickListener(function()
    import "android.app.AlertDialog"
    import "android.widget.ArrayAdapter"
    local appList = pm.queryIntentActivities(Intent(Intent.ACTION_MAIN, nil).addCategory(Intent.CATEGORY_LAUNCHER), 0)
    local data, labels = {}, {}
    for i=0, appList.size()-1 do
      local info = appList.get(i)
      table.insert(data, info.activityInfo.packageName)
      table.insert(labels, tostring(info.loadLabel(pm)))
    end

    AlertDialog.Builder(activity)
    .setTitle("เลือกแอป")
    .setAdapter(ArrayAdapter(activity, android.R.layout.select_dialog_item, labels), function(d, which)
      local pkg = data[which+1]
      local fa = io.open(filePath, "a")
      if fa then
        fa:write(pkg .. "\n")
        fa:close()
      end
      loadManualGames(activity)
    end).show()
  end)

  manualContainer.addView(addBtn)
  manualContainer.requestLayout()
end

local function getNoticeFromGitHub()
  -- ใช้ Thread เพื่อดึงข้อมูล จะช่วยให้แอปไม่ค้างและโหลดข้อมูลได้ดีขึ้น
  local content = "กำลังโหลดประกาศ..."
  Thread(function()
    local ok, res = pcall(function() return http.get("https://raw.githubusercontent.com/narunataorgh-crypto/app-update/refs/heads/main/notice_data.txt") end)
    if ok and res then
      -- อัปเดตข้อความบน UI Thread
      activity.runOnUiThread(function()
        contentText.setText(res)
      end)
     else
      activity.runOnUiThread(function()
        contentText.setText("ไม่สามารถโหลดประกาศได้ (ตรวจสอบเน็ต)")
      end)
    end
  end).start()
  return content
end

local function showLauncherUI(activity, rootLayout)
  local scroll = ScrollView(activity)
  local bgPath = activity.getLuaDir() .. "/res/bg.png"

  -- ใช้ BitmapFactory เพื่อโหลดภาพแบบย่อขนาดป้องกัน RAM เต็ม
  local opts = BitmapFactory.Options()
  opts.inSampleSize = 2 -- ลองปรับเป็น 2 ถ้ายัง Error ให้ปรับเป็น 4
  local bmp = BitmapFactory.decodeFile(bgPath, opts)

  if bmp then
    scroll.setBackgroundDrawable(BitmapDrawable(activity.getResources(), bmp))
   else
    scroll.setBackgroundColor(0xFF000000)
  end

  local layout = LinearLayout(activity)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(30, 30, 30, 30)
  scroll.addView(layout)

  -- 1. หัวข้อ (บนสุด)
  local title = TextView(activity)
  title.setText("🎮 เลือกเกมของคุณ")
  title.setTextSize(22)
  title.setTextColor(0xFFFFFFFF)
  layout.addView(title)

  -- 2. รายการเกม
  local gameContainer = LinearLayout(activity)
  gameContainer.setOrientation(LinearLayout.VERTICAL)
  layout.addView(gameContainer)

  local gameData = {
    {category="MOBA", games={{name="GARENA ROV", color="#442233", icon="rov.png", pkg="com.garena.game.kgth"}, {name="League of Legends: Wild Rift", color="#224433", icon="lol.png", pkg="com.riotgames.league.wildrift"},{name="Honor of Kings(🌎)", color="#442233", icon="hok.png", pkg="com.levelinfinite.sgameGlobal"},{name="Honor of Kings(🇨🇳)", color="#442233", icon="hok.png", pkg="com.tencent.tmgp.sgame"},{name="Onmyoji Arena", color="#442233", icon="ona.png", pkg="com.netease.g78na.gb"}}},
    {category="FPS / Action", games={{name="PUBG MOBILE", color="#224433", icon="pubg.png", pkg="com.tencent.ig"}, {name="FREE FIRE", color="#224433", icon="freefire.png", pkg="com.dts.freefireth"}, {name="CALL OF DUTY", color="#334422", icon="cod.png", pkg="com.garena.game.codm"}, {name="Delta Force", color="#224433", icon="deltaforce.png", pkg="com.garena.game.df"}}},
    {category="RPG / Open World", games={{name="Genshin Impact", color="#442233", icon="genshin.png", pkg="com.miHoYo.GenshinImpact"}, {name="Wuthering Waves", color="#224433", icon="wuwa.png", pkg="com.kurogame.wutheringwaves.global"}, {name="RF ONLINE NEXT", color="#224433", icon="rf.png", pkg="com.netmarble.rfnext"}}},
    {category="Sports", games={{name="eFootball", color="#663322", icon="efootball.png", pkg="jp.konami.pesam"}}}
  }

  local gameCache = {}

  local function renderGames()
    for _, group in ipairs(gameData) do
      local categoryBtn = Button(activity)
      categoryBtn.setText("📂 " .. group.category)
      categoryBtn.setBackgroundColor(0xFF222222)
      categoryBtn.setTextColor(0xFF00FF00)
      local subContainer = LinearLayout(activity)
      subContainer.setOrientation(LinearLayout.VERTICAL)
      subContainer.setVisibility(View.GONE)
      categoryBtn.setOnClickListener(function()
        subContainer.setVisibility(subContainer.getVisibility() == View.VISIBLE and View.GONE or View.VISIBLE)
      end)
      for _, game in ipairs(group.games) do
        if not gameCache[game.name] then
          local isInstalled = false
          pcall(function() activity.getPackageManager().getPackageInfo(game.pkg, 0); isInstalled = true end)
          local iconDrawable = nil
          pcall(function()
            local bmp = BitmapFactory.decodeFile(activity.getLuaDir() .. "/icon_game/" .. game.icon)
            if bmp then iconDrawable = BitmapDrawable(activity.getResources(), bmp); iconDrawable.setBounds(0, 0, 80, 80) end
          end)
          gameCache[game.name] = {installed = isInstalled, icon = iconDrawable}
        end
        local data = gameCache[game.name]
        local btn = Button(activity)
        if data.icon then btn.setCompoundDrawables(data.icon, nil, nil, nil); btn.setCompoundDrawablePadding(20) end
        btn.setText(data.installed and game.name or (game.name .. "\n(กรุณาติดตั้งเกม)"))
        btn.setBackgroundColor(data.installed and Color.parseColor(game.color) or 0xFF555555)
        btn.setOnClickListener(function()
          activity.startActivity(data.installed and activity.getPackageManager().getLaunchIntentForPackage(game.pkg) or Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" .. game.pkg)))
        end)
        subContainer.addView(btn)
      end
      gameContainer.addView(categoryBtn)
      gameContainer.addView(subContainer)
    end
  end
  renderGames()

  -- 3. เส้นคั่น (Divider)
  local divider = View(activity)
  divider.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 4))
  divider.setBackgroundColor(0xFF888888)
  local margin = LinearLayout.LayoutParams(divider.getLayoutParams())
  margin.setMargins(0, 20, 0, 20)
  divider.setLayoutParams(margin)
  layout.addView(divider)

  -- [ส่วนที่ 3.5] ระบบเพิ่มเกมโปรดเอง
  local titleManual = TextView(activity)
  titleManual.setText("🎮 เกมและแอปโปรด (เพิ่มเอง)")
  titleManual.setTextColor(0xFF00FF00)
  layout.addView(titleManual)

  local frameDrawable = GradientDrawable()
  frameDrawable.setShape(GradientDrawable.RECTANGLE)
  frameDrawable.setCornerRadius(20)
  frameDrawable.setStroke(4, 0xFF00FF00)
  frameDrawable.setColor(0x40000000)

  manualContainer = GridLayout(activity)
  -- ใช้ความกว้าง MATCH_PARENT (-1) เพื่อให้มันยืดเต็มหน้าจอ
  local params = LinearLayout.LayoutParams(-1, -2)
  manualContainer.setLayoutParams(params)

  manualContainer.setColumnCount(4)

  -- ปรับ Padding ให้เล็กลงเพื่อให้มีพื้นที่วางไอคอนมากขึ้น
  manualContainer.setPadding(10, 10, 10, 10)

  manualContainer.setBackgroundDrawable(frameDrawable)
  layout.addView(manualContainer)

  -- โหลดครั้งแรก
  loadManualGames(activity)

  -- 3. เส้นคั่น (Divider)
  local divider = View(activity)
  divider.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 4))
  divider.setBackgroundColor(0xFF888888)
  local margin = LinearLayout.LayoutParams(divider.getLayoutParams())
  margin.setMargins(0, 20, 0, 20)
  divider.setLayoutParams(margin)
  layout.addView(divider)

  -- 4. กรอบคำเตือน (ล่างสุด) - ปรับเป็นกรอบมีเส้นขอบและพื้นหลังโปร่งแสง
  local drawable = GradientDrawable()
  drawable.setShape(GradientDrawable.RECTANGLE)
  drawable.setCornerRadius(20) -- ความมนของมุมกรอบ
  drawable.setStroke(4, 0xFF00FF00) -- เส้นขอบสีเขียว หนา 4px
  drawable.setColor(0x40000000) -- พื้นหลังสีดำโปร่งแสง (ค่า 40 คือความโปร่ง)

  local warningLayout = LinearLayout(activity)
  warningLayout.setOrientation(LinearLayout.VERTICAL)
  warningLayout.setBackgroundDrawable(drawable) -- ใช้งาน Drawable ที่สร้างขึ้น
  warningLayout.setPadding(30, 30, 30, 30)

  local labelText = TextView(activity)
  labelText.setText("📢 ประกาศ: ")
  labelText.setTextColor(0xFFFF0000)
  labelText.setTypeface(nil, Typeface.BOLD)
  warningLayout.addView(labelText)

  local contentText = TextView(activity)
  contentText.setTextColor(0xFFFFFFFF)
  warningLayout.addView(contentText)

  Thread(function()
    local url = "https://raw.githubusercontent.com/narunataorgh-crypto/app-update/refs/heads/main/notice_data.txt"

    -- วิธีนี้คือการใช้ callback function แทนการใช้ .execute()
    Http.get(url, function(code, content)
      activity.runOnUiThread(function()
        if code == 200 then
          contentText.setText(tostring(content))
         else
          contentText.setText("Error: ไม่สามารถเชื่อมต่อได้ (Code: " .. tostring(code) .. ")")
        end
      end)
    end)
  end).start()

  layout.addView(warningLayout)

  activity.setContentView(scroll)
end

function gamemode.toggle(activity, isCurrentlyActive, rootLayout)
  -- ส่วนของฟังก์ชัน toggle เดิมของคุณที่นี่...
  if isCurrentlyActive then
    -- [ส่วนเปิดโหมดเกม]

    -- 1. ซ่อนแถบสถานะ (Status Bar) และแถบนำทาง (Navigation Bar) เพื่อให้เต็มจอ
    local decorView = activity.getWindow().getDecorView()
    decorView.setSystemUiVisibility(
    View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | -- ซ่อนแถบสีขาวข้างล่าง
    View.SYSTEM_UI_FLAG_FULLSCREEN | -- ซ่อนแถบสถานะข้างบน
    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY -- ให้ซ่อนกลับอัตโนมัติถ้ามีแถบโผล่มา
    )

    local videoLayout = FrameLayout(activity)
    videoLayout.setLayoutParams(FrameLayout.LayoutParams(-1, -1))

    import "android.widget.VideoView"
    import "android.widget.FrameLayout"

    local videoView = VideoView(activity)
    local videoPath = activity.getLuaDir() .. "/res/bg.mp4"
    videoView.setVideoPath(videoPath)

    local params = FrameLayout.LayoutParams(-1, -1)
    videoView.setLayoutParams(params)

    videoView.setOnPreparedListener(MediaPlayer.OnPreparedListener({
      onPrepared = function(mp)
        local videoWidth = mp.getVideoWidth()
        local videoHeight = mp.getVideoHeight()
        local screenWidth = activity.getWindowManager().getDefaultDisplay().getWidth()
        local screenHeight = activity.getWindowManager().getDefaultDisplay().getHeight()

        -- เปลี่ยนมาใช้ math.max เพื่อให้วิดีโอขยายจน "เต็มพื้นที่" แม้จะต้องตัดขอบออกบ้าง
        local scaleX = screenWidth / videoWidth
        local scaleY = screenHeight / videoHeight
        local scale = math.max(scaleX, scaleY)

        videoView.setScaleX(scale)
        videoView.setScaleY(scale)

        -- ปรับให้อยู่กึ่งกลางหน้าจอเสมอ
        videoView.setPivotX(videoWidth / 2)
        videoView.setPivotY(videoHeight / 2)

        mp.setLooping(false)
        videoView.start()
      end
    }))

    videoView.setOnCompletionListener(MediaPlayer.OnCompletionListener({
      onCompletion = function(mp)
        -- วิดีโอเล่นจบ ให้คืนค่าแถบระบบกลับมาและโชว์หน้า Launcher
        decorView.setSystemUiVisibility(0)
        mp.release()
        showLauncherUI(activity, rootLayout)
      end
    }))

    videoLayout.addView(videoView)
    activity.setContentView(videoLayout)

   else
    -- [ส่วนกดปิดโหมดเกม]
    isGameModeActive = false
    -- คืนค่าแถบระบบกลับมาปกติ
    activity.getWindow().getDecorView().setSystemUiVisibility(0)
    activity.setContentView(rootLayout)
    Toast.makeText(activity, "ปิดโหมดเกมแล้ว", Toast.LENGTH_SHORT).show()
  end
end

return gamemode

