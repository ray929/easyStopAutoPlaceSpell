-- easyStopAutoPlaceSpell/easyStopAutoPlaceSpell.lua
-- 阻止新学习技能自动添加到动作栏：移植自 DisableAutoAddSpells（luo）。
-- 常驻生效：无配置界面、无存档、无游戏内开关。
--
-- 原理（从源头阻止，不破坏暴雪全局状态）：
--   零售端「新技能自动入条」由暴雪追踪器 IconIntroTracker 在其 OnEvent 处理
--   SPELL_PUSHED_TO_ACTIONBAR 时完成（payload: spellID, slot, page）。
--   ① 把 IconIntroTracker 的 OnEvent 脚本替换为包装函数：遇到该事件直接跳过（不转发），
--      从源头掐断自动添加；其余事件原样转发给原始脚本。
--   ② 同时自建监听帧兜底：事件触发（非战斗且有 slot）时 PickupAction + ClearCursor 撤销残留。
--
--   ⚠️ 客户端把该行为绑定在【登录会话】上：本插件停用后仅 ReloadUI 不足以恢复自动入条，
--      必须小退重新登陆才生效（已实测）。故本插件不提供「关闭」开关，停用即需小退重登。

local hooked      = false   -- 是否已替换 IconIntroTracker.OnEvent
local origOnEvent = nil     -- 原始 OnEvent 脚本

-- IconIntroTracker 的 OnEvent 包装：跳过 SPELL_PUSHED_TO_ACTIONBAR，其余原样转发
local function TrackerOnEvent(self, event, ...)
    if event == "SPELL_PUSHED_TO_ACTIONBAR" then
        return
    end
    if origOnEvent then
        origOnEvent(self, event, ...)
    end
end

-- 兜底监听帧：撤销任何仍被推入槽位的技能（taint-safe）
local undoFrame = CreateFrame("Frame")
local function OnSpellPushed(_, _, _, slot)
    if not InCombatLockdown() and slot then
        ClearCursor()
        PickupAction(slot)
        ClearCursor()
    end
end

-- 从源头掐断自动添加：替换 IconIntroTracker.OnEvent
local function Start()
    if not hooked then
        if IconIntroTracker then
            origOnEvent = IconIntroTracker:GetScript("OnEvent")
            IconIntroTracker:SetScript("OnEvent", TrackerOnEvent)
        end
        undoFrame:SetScript("OnEvent", OnSpellPushed)
        hooked = true
    end
    undoFrame:RegisterEvent("SPELL_PUSHED_TO_ACTIONBAR")
end

-- PLAYER_LOGIN 时 IconIntroTracker 已存在
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    Start()
end)
