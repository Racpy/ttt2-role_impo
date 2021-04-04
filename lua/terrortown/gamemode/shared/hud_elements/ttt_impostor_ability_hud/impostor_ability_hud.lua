local base = "pure_skin_element"

DEFINE_BASECLASS(base)

HUDELEMENT.Base = base

--Most code here is taken from Beacon HUD logic.
if CLIENT then
	local pad = 7
	local iconSize = 64
	--Used for Insta Kill and Venting
	local icon_kill_waiting = Material("vgui/ttt/dynamic/roles/icon_impo")
	local icon_kill_ready = Material("vgui/ttt/dynamic/roles/icon_traitor")
	local icon_in_vent = Material("vgui/ttt/icon_vent")
	--Used for Sabotage Lights
	local icon_lit_bulb = Material("vgui/ttt/icon_lit_bulb")
	local icon_unlit_bulb = Material("vgui/ttt/icon_unlit_bulb")
	--Used for Sabotage O2
	local icon_o2_safe = Material("vgui/ttt/icon_o2_safe")
	local icon_o2_unsafe = Material("vgui/ttt/icon_react")
	--Used for Sabotage Reactor
	local icon_react = Material("vgui/ttt/icon_react")
	
	local const_defaults = {
		basepos = {x = 0, y = 0},
		size = {w = 365, h = 32},
		minsize = {w = 225, h = 32}
	}

	function HUDELEMENT:PreInitialize()
		BaseClass.PreInitialize(self)

		local hud = huds.GetStored("pure_skin")
		if not hud then return end

		hud:ForceElement(self.id)
	end

	function HUDELEMENT:Initialize()
		self.scale = 1.0
		self.basecolor = self:GetHUDBasecolor()
		self.pad = pad
		self.iconSize = iconSize

		BaseClass.Initialize(self)
	end

	-- parameter overwrites
	function HUDELEMENT:IsResizable()
		return true, false
	end
	-- parameter overwrites end

	function HUDELEMENT:GetDefaults()
		const_defaults["basepos"] = {
			x = 10 * self.scale,
			y = ScrH() - self.size.h - 146 * self.scale - self.pad - 10 * self.scale
		}

		return const_defaults
	end

	function HUDELEMENT:PerformLayout()
		self.scale = self:GetHUDScale()
		self.basecolor = self:GetHUDBasecolor()
		self.iconSize = iconSize * self.scale
		self.pad = pad * self.scale

		BaseClass.PerformLayout(self)
	end

	function HUDELEMENT:ShouldDraw()
		local client = LocalPlayer()
		
		return HUDEditor.IsEditing or (client:Alive() and client:GetSubRole() == ROLE_IMPOSTOR)
	end
	
	local function IsInSpecDM(ply)
		if SpecDM and (ply.IsGhost and ply:IsGhost()) then
			return true
		end
		
		return false
	end
	
	function HUDELEMENT:DrawComponent(text, bg_color, icon_color, icon, first_bar)
		local pos = self:GetPos()
		local size = self:GetSize()
		local x, y = pos.x, pos.y
		local w, h = size.w, size.h
		if not first_bar then
			y = y - (self.size.h + self.pad + 10 * self.scale)
		end
		
		self:DrawBg(x, y, w, h, bg_color)
		draw.AdvancedText(text, "PureSkinBar", x + self.iconSize + self.pad, y + h * 0.5, util.GetDefaultColor(bg_color), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, true, self.scale)
		self:DrawLines(x, y, w, h, self.basecolor.a)
		
		local nSize = self.iconSize - 16
		
		draw.FilteredShadowedTexture(x, y - 2 - (nSize - h), nSize, nSize, icon, 255, icon_color, self.scale)
	end
	
	local function TimeLeftToString(time_left)
		return " (" .. math.ceil(math.abs(time_left)) .. ")"
	end
	
	function HUDELEMENT:DrawInstaKillComponent()
		local client = LocalPlayer()
		local icon_color = COLOR_BLACK
		local kill_str = LANG.GetTranslation("KILL_" .. IMPOSTOR.name)
		local bg_color = COLOR_LGRAY
		if client.impo_can_insta_kill then
			bg_color = IMPOSTOR.color
		end
		local icon = nil
		
		--Venting GUI has priority over insta-kill
		if IsValid(client.impo_in_vent) then
			icon = icon_in_vent
			bg_color = COLOR_ORANGE
		elseif client.impo_can_insta_kill then
			icon = icon_kill_ready
		else
			icon = icon_kill_waiting
		end
		
		--Display time left if possible.
		if not client.impo_can_insta_kill and timer.Exists("ImpostorKillTimer_Client_" .. client:SteamID64()) then
			local time_left = timer.TimeLeft("ImpostorKillTimer_Client_" .. client:SteamID64())
			kill_str = kill_str .. TimeLeftToString(time_left)
		elseif client.impo_can_insta_kill then
			local kill_key = string.upper(input.GetKeyName(bind.Find("ImpostorSendInstantKillRequest")))
			kill_str = kill_str .. " (" .. LANG.GetTranslation("PRESS_" .. IMPOSTOR.name) .. kill_key .. ")"
		end
		
		self:DrawComponent(kill_str, bg_color, icon_color, icon, true)
	end
	
	function HUDELEMENT:DrawSabotageStationManagerComponent()
		local icon_color = COLOR_BLACK
		local sabo_key = string.upper(input.GetKeyName(bind.Find("ImpostorSendSabotageRequest")))
		local sabo_str = LANG.GetTranslation("SABO_MNGR_" .. IMPOSTOR.name) .. " (" .. LANG.GetTranslation("PRESS_" .. IMPOSTOR.name) .. sabo_key .. ")"
		local bg_color = COLOR_LGRAY
		local icon = icon_kill_waiting
		
		self:DrawComponent(sabo_str, bg_color, icon_color, icon, false)
	end
	
	function HUDELEMENT:DrawSabotageLightsComponent()
		local icon_color = COLOR_WHITE
		local sabo_str = LANG.GetTranslation("SABO_LIGHTS_" .. IMPOSTOR.name)
		local bg_color = Color(255, 255, 153, 255) --Beacon's color
		local icon = icon_lit_bulb
		
		if timer.Exists("ImpostorSaboTimer_Client") then
			--Sabotage is on cooldown
			local time_left = timer.TimeLeft("ImpostorSaboTimer_Client")
			sabo_str = sabo_str .. TimeLeftToString(time_left)
			bg_color = COLOR_LGRAY
		elseif timer.Exists("ImpostorSaboLightsTimer_Client") then
			--Sabotage is in progress.
			local sabo_lights_mode = GetConVar("ttt2_impostor_sabo_lights_mode"):GetInt()
			local sabo_lights_len = GetConVar("ttt2_impostor_sabo_lights_length"):GetFloat()
			local time_left = timer.TimeLeft("ImpostorSaboLightsTimer_Client")
			
			if sabo_lights_mode == SABO_LIGHTS_MODE.DISABLE_MAP then
				--Lights are abruptly shut off.
				bg_color = COLOR_BLACK
				icon_color = COLOR_LGRAY
				icon = icon_unlit_bulb
				
				--Give seconds left until darkness lifts
				sabo_str = sabo_str .. TimeLeftToString(time_left)
			else --SABO_LIGHTS_MODE.SCREEN_FADE
				local fade_time = GetConVar("ttt2_impostor_sabo_lights_fade"):GetFloat()
				
				if time_left > sabo_lights_len + fade_time then
					--Screen is transitioning to complete darkness
					local fract = (time_left - (sabo_lights_len + fade_time)) / fade_time
					local h, s, v = ColorToHSV(bg_color)
					bg_color = HSVToColor(h, s, v * fract)
					
					icon_color = COLOR_LGRAY
					icon = icon_unlit_bulb
				elseif time_left <= fade_time then
					--Screen is transitioning from complete darkness
					local fract = 1 - (time_left / fade_time)
					if GetConVar("ttt2_impostor_sabo_lights_cooldown"):GetInt() > 0 then
						bg_color = COLOR_LGRAY
					end
					local h, s, v = ColorToHSV(bg_color)
					bg_color = HSVToColor(h, s, v * fract)
				else
					--Screen is completely dark.
					bg_color = COLOR_BLACK
					icon_color = COLOR_LGRAY
					icon = icon_unlit_bulb
					
					--Give seconds left until darkness lifts
					sabo_str = sabo_str .. TimeLeftToString(time_left - fade_time)
				end
			end
		else
			--Sabotage is ready to go
			local sabo_key = string.upper(input.GetKeyName(bind.Find("ImpostorSendSabotageRequest")))
			sabo_str = sabo_str .. " (" .. LANG.GetTranslation("PRESS_" .. IMPOSTOR.name) .. sabo_key .. ")"
		end
		
		self:DrawComponent(sabo_str, bg_color, icon_color, icon, false)
	end
	
	function HUDELEMENT:DrawSabotageCommsComponent()
		local icon_color = COLOR_BLACK
		local sabo_str = LANG.GetTranslation("SABO_COMMS_" .. IMPOSTOR.name)
		local bg_color = COLOR_WHITE
		local icon = icon_lit_bulb
		
		if timer.Exists("ImpostorSaboTimer_Client") then
			--Sabotage is on cooldown
			local time_left = timer.TimeLeft("ImpostorSaboTimer_Client")
			sabo_str = sabo_str .. TimeLeftToString(time_left)
			bg_color = COLOR_LGRAY
		elseif timer.Exists("ImpostorSaboCommsTimer_Client") then
			--Sabotage is in progress.
			local time_left = timer.TimeLeft("ImpostorSaboCommsTimer_Client")
			
			--Comms are hacked, and so bg is Impostor's color
			bg_color = IMPOSTOR.color
			icon = icon_unlit_bulb
			
			--Give seconds left until comms are operational again
			sabo_str = sabo_str .. TimeLeftToString(time_left)
		else
			--Sabotage is ready to go
			local sabo_key = string.upper(input.GetKeyName(bind.Find("ImpostorSendSabotageRequest")))
			sabo_str = sabo_str .. " (" .. LANG.GetTranslation("PRESS_" .. IMPOSTOR.name) .. sabo_key .. ")"
		end
		
		self:DrawComponent(sabo_str, bg_color, icon_color, icon, false)
	end
	
	function HUDELEMENT:DrawSabotageO2Component()
		local icon_color = COLOR_WHITE
		local sabo_str = LANG.GetTranslation("SABO_O2_" .. IMPOSTOR.name)
		local bg_color = COLOR_BLUE
		local icon = icon_o2_safe
		
		if timer.Exists("ImpostorSaboTimer_Client") then
			--Sabotage is on cooldown
			local time_left = timer.TimeLeft("ImpostorSaboTimer_Client")
			sabo_str = sabo_str .. TimeLeftToString(time_left)
			bg_color = COLOR_LGRAY
		elseif timer.Exists("ImpostorSaboO2Timer_Client") then
			--Sabotage is in progress.
			local time_left = timer.TimeLeft("ImpostorSaboO2Timer_Client")
			
			--Air is hazaradous.
			bg_color = COLOR_YELLOW
			icon = icon_o2_unsafe
			icon_color = COLOR_BLACK
			
			--Give seconds left until darkness lifts
			sabo_str = sabo_str .. TimeLeftToString(time_left)
		else
			--Sabotage is ready to go
			local sabo_key = string.upper(input.GetKeyName(bind.Find("ImpostorSendSabotageRequest")))
			sabo_str = sabo_str .. " (" .. LANG.GetTranslation("PRESS_" .. IMPOSTOR.name) .. sabo_key .. ")"
		end
		
		self:DrawComponent(sabo_str, bg_color, icon_color, icon, false)
	end
	
	function HUDELEMENT:DrawSabotageReactComponent()
		local icon_color = COLOR_BLACK
		local sabo_str = LANG.GetTranslation("SABO_REACT_" .. IMPOSTOR.name)
		local bg_color = COLOR_GREEN
		local icon = icon_react
		
		if timer.Exists("ImpostorSaboTimer_Client") then
			--Sabotage is on cooldown
			local time_left = timer.TimeLeft("ImpostorSaboTimer_Client")
			sabo_str = sabo_str .. TimeLeftToString(time_left)
			bg_color = COLOR_LGRAY
		elseif timer.Exists("ImpostorSaboReactTimer_Client") then
			--Sabotage is in progress.
			local time_left = timer.TimeLeft("ImpostorSaboReactTimer_Client")
			
			--Alert!
			bg_color = COLOR_YELLOW
			if math.ceil(time_left) % 2 == 0 then
				bg_color = IMPOSTOR.color
			end
			
			--Give seconds left until darkness lifts
			sabo_str = sabo_str .. TimeLeftToString(time_left)
		else
			--Sabotage is ready to go
			local sabo_key = string.upper(input.GetKeyName(bind.Find("ImpostorSendSabotageRequest")))
			sabo_str = sabo_str .. " (" .. LANG.GetTranslation("PRESS_" .. IMPOSTOR.name) .. sabo_key .. ")"
		end
		
		self:DrawComponent(sabo_str, bg_color, icon_color, icon, false)
	end
	
	function HUDELEMENT:DrawStrangeGameComponent()
		local icon_color = COLOR_GREEN
		local sabo_str = LANG.GetTranslation("SABO_REACT_STRANGE_GAME" .. IMPOSTOR.name)
		local bg_color = COLOR_BLACK
		local icon = icon_react
		
		self:DrawComponent(sabo_str, bg_color, icon_color, icon, false)
	end
	
	function HUDELEMENT:Draw()
		local client = LocalPlayer()
		local sabo_in_progress = IMPO_SABO_DATA.CurrentSabotageInProgress()
		
		if IsInSpecDM(client) then
			return
		end
		
		self:DrawInstaKillComponent()
		if IMPO_SABO_DATA.STRANGE_GAME then
			self:DrawStrangeGameComponent()
		elseif client.impo_sabo_mode == SABO_MODE.MNGR and sabo_in_progress == SABO_MODE.NONE then
			self:DrawSabotageStationManagerComponent()
		elseif (client.impo_sabo_mode == SABO_MODE.LIGHTS and sabo_in_progress == SABO_MODE.NONE) or sabo_in_progress == SABO_MODE.LIGHTS then
			self:DrawSabotageLightsComponent()
		elseif (client.impo_sabo_mode == SABO_MODE.COMMS and sabo_in_progress == SABO_MODE.NONE) or sabo_in_progress == SABO_MODE.COMMS then
			self:DrawSabotageCommsComponent()
		elseif (client.impo_sabo_mode == SABO_MODE.O2 and sabo_in_progress == SABO_MODE.NONE) or sabo_in_progress == SABO_MODE.O2 then
			self:DrawSabotageO2Component()
		elseif (client.impo_sabo_mode == SABO_MODE.REACT and sabo_in_progress == SABO_MODE.NONE) or sabo_in_progress == SABO_MODE.REACT then
			self:DrawSabotageReactComponent()
		end
	end
end