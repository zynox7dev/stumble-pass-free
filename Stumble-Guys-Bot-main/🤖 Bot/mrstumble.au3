#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

HotKeySet("{F9}", "_TogglePause")
HotKeySet("{F10}", "_Terminate")

Global $title = "Stumble Guys"
Global $hWnd = 0
Global $baseWidth = 1920
Global $baseHeight = 1080
Global $windowWidth = 1920
Global $windowHeight = 1080
Global $centerX = Round($baseWidth/2)
Global $centerY = Round($baseHeight/2)
Global $configFile = @ScriptDir & "\StumbleBot.ini"
Global $logFile = @ScriptDir & "\StumbleBot.log"
Global $logHandle = -1
Global $maxRounds = 0
Global $maxMinutes = 0
Global $toleranceAdjustment = 0
Global $roundsCompleted = 0
Global $roundCounted = 1
Global $sessionStarted = 0
Global $sessionTimer = 0
Global $paused = 0
Global $guiHandle = 0
Global $statusLabel = 0
Global $statsLabel = 0
Global $roundsInput = 0
Global $minutesInput = 0
Global $toleranceInput = 0
Global $saveButton = 0
Global $startButton = 0
Global $pauseButton = 0
Global $stopButton = 0
Global $botStarted = 0
Global $refreshTimer = TimerInit()
Global $lastCalibrationStatus = ""

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Main loop

_Initialize()
_Main()

Func _Initialize()
	_LoadConfiguration()
	$logHandle = FileOpen($logFile, 1 + 8)
	If $logHandle = -1 Then
		ConsoleWrite("ERROR: Could not open log file: " & $logFile & @CRLF)
		Exit
	EndIf

	OnAutoItExitRegister("_Cleanup")
	_CreateControlWindow()
	Debug("Bot ready. Press Start in the control window.")
EndFunc

Func _CreateControlWindow()
	$guiHandle = GUICreate("Stumble Guys Bot", 380, 235, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))
	GUICtrlCreateLabel("Session limits (0 = unlimited)", 18, 18, 300, 20)
	GUICtrlCreateLabel("Rounds", 18, 48, 90, 20)
	$roundsInput = GUICtrlCreateInput(String($maxRounds), 110, 45, 85, 24)
	GUICtrlCreateLabel("Minutes", 205, 48, 65, 20)
	$minutesInput = GUICtrlCreateInput(String($maxMinutes), 275, 45, 85, 24)
	GUICtrlCreateLabel("Pixel tolerance adjustment (-10 to 30)", 18, 80, 260, 20)
	$toleranceInput = GUICtrlCreateInput(String($toleranceAdjustment), 275, 77, 85, 24)
	$saveButton = GUICtrlCreateButton("Save settings", 18, 112, 105, 30)
	$startButton = GUICtrlCreateButton("Start", 135, 112, 85, 30)
	$pauseButton = GUICtrlCreateButton("Pause (F9)", 230, 112, 90, 30)
	$stopButton = GUICtrlCreateButton("Stop (F10)", 18, 153, 105, 30)
	$statusLabel = GUICtrlCreateLabel("Ready. Save settings, then press Start.", 18, 190, 340, 20)
	$statsLabel = GUICtrlCreateLabel("Rounds: 0 | Elapsed: 00:00:00", 18, 211, 340, 20)
	GUICtrlSetState($pauseButton, $GUI_DISABLE)
	GUISetState(@SW_SHOW, $guiHandle)
EndFunc

Func _Main()
	Opt("MouseCoordMode", 2)
	Opt("PixelCoordMode", 2)
	Opt("SendKeyDownDelay", 25)

	While Not $botStarted
		_ProcessControls()
		Sleep(100)
	WEnd

	While $botStarted
		_ProcessControls()
		If WinExists($title) = 0 Then
			If $hWnd <> 0 Then
				Debug("Game window closed. Stopping.")
				Exit
			EndIf
			_SetStatus("Waiting for the Stumble Guys window.")
			_Sleep(1000)
			ContinueLoop
		EndIf

		If WinActive($title) = 0 Then
			_ReleaseKeys()
			_SetStatus("Waiting for the game window to have focus.")
			_Sleep(500)
			ContinueLoop
		EndIf

		If _CalibrateScreen() = 0 Then
			_Sleep(1000)
			ContinueLoop
		EndIf

		HandleAdvert()
		HandleLevelUp()
		HandleItemReceived()

		If DetectMainMenu() = 1 Then
			Debug("Detect: Main Menu")

			HandleMissionRewards()

			$roundCounted = 0
			ClickPlayGame()
			_Sleep(1000)

			HandleGameLoad()
		EndIf

		GameLoop()
		_Sleep(500)
	WEnd
EndFunc

Func _LoadConfiguration()
	If Not FileExists($configFile) Then
		If Not IniWrite($configFile, "Session", "MaxRounds", "0") Or _
			Not IniWrite($configFile, "Session", "MaxMinutes", "0") Or _
			Not IniWrite($configFile, "Detection", "ToleranceAdjustment", "0") Then
			ConsoleWrite("ERROR: Could not create configuration file: " & $configFile & @CRLF)
			Exit
		EndIf
	EndIf

	Local $rounds = IniRead($configFile, "Session", "MaxRounds", "0")
	Local $minutes = IniRead($configFile, "Session", "MaxMinutes", "0")
	Local $tolerance = IniRead($configFile, "Detection", "ToleranceAdjustment", "0")

	If StringIsInt($rounds) And Number($rounds) >= 0 Then
		$maxRounds = Number($rounds)
	Else
		ConsoleWrite("WARNING: Invalid MaxRounds in configuration; using 0 (unlimited)." & @CRLF)
		If Not IniWrite($configFile, "Session", "MaxRounds", "0") Then ConsoleWrite("ERROR: Could not repair MaxRounds in " & $configFile & @CRLF)
	EndIf

	If StringIsInt($minutes) And Number($minutes) >= 0 Then
		$maxMinutes = Number($minutes)
	Else
		ConsoleWrite("WARNING: Invalid MaxMinutes in configuration; using 0 (unlimited)." & @CRLF)
		If Not IniWrite($configFile, "Session", "MaxMinutes", "0") Then ConsoleWrite("ERROR: Could not repair MaxMinutes in " & $configFile & @CRLF)
	EndIf

	If StringIsInt($tolerance) And Number($tolerance) >= -10 And Number($tolerance) <= 30 Then
		$toleranceAdjustment = Number($tolerance)
	Else
		ConsoleWrite("WARNING: Invalid ToleranceAdjustment; using 0." & @CRLF)
		If Not IniWrite($configFile, "Detection", "ToleranceAdjustment", "0") Then ConsoleWrite("ERROR: Could not repair ToleranceAdjustment in " & $configFile & @CRLF)
	EndIf
EndFunc

Func _ProcessControls()
	Local $message = GUIGetMsg()
	Switch $message
		Case $GUI_EVENT_CLOSE, $stopButton
			_Terminate()
		Case $saveButton
			_SaveConfiguration()
		Case $startButton
			_StartBot()
		Case $pauseButton
			_TogglePause()
	EndSwitch
	_RefreshDashboard()
	_CheckSessionLimits()
EndFunc

Func _SaveConfiguration()
	Local $rounds = GUICtrlRead($roundsInput)
	Local $minutes = GUICtrlRead($minutesInput)
	Local $tolerance = GUICtrlRead($toleranceInput)

	If Not StringIsInt($rounds) Or Number($rounds) < 0 Then
		_SetStatus("Rounds must be a whole number (0 or greater).")
		Debug("Invalid rounds setting: " & $rounds)
		Return 0
	EndIf
	If Not StringIsInt($minutes) Or Number($minutes) < 0 Then
		_SetStatus("Minutes must be a whole number (0 or greater).")
		Debug("Invalid minutes setting: " & $minutes)
		Return 0
	EndIf
	If Not StringIsInt($tolerance) Or Number($tolerance) < -10 Or Number($tolerance) > 30 Then
		_SetStatus("Tolerance adjustment must be between -10 and 30.")
		Debug("Invalid tolerance adjustment: " & $tolerance)
		Return 0
	EndIf

	If Not IniWrite($configFile, "Session", "MaxRounds", $rounds) Or _
		Not IniWrite($configFile, "Session", "MaxMinutes", $minutes) Or _
		Not IniWrite($configFile, "Detection", "ToleranceAdjustment", $tolerance) Then
		_SetStatus("Could not save settings. Check folder permissions.")
		Debug("ERROR: Failed to write configuration file: " & $configFile)
		Return 0
	EndIf

	$maxRounds = Number($rounds)
	$maxMinutes = Number($minutes)
	$toleranceAdjustment = Number($tolerance)
	_SetStatus("Settings saved.")
	Debug("Settings saved.")
	Return 1
EndFunc

Func _StartBot()
	If $botStarted Then Return
	If _SaveConfiguration() = 0 Then Return

	$botStarted = 1
	$sessionStarted = 1
	$sessionTimer = TimerInit()
	GUICtrlSetState($startButton, $GUI_DISABLE)
	GUICtrlSetState($pauseButton, $GUI_ENABLE)
	_SetStatus("Started. Activate the Stumble Guys window.")
	Debug("Session started.")
EndFunc

Func _TogglePause()
	If Not $botStarted Then Return

	$paused = Not $paused
	If $paused Then
		_ReleaseKeys()
		_SetStatus("Paused. Press F9 or Resume to continue.")
		Debug("Bot paused.")
	Else
		_SetStatus("Resumed. Activate the game window to continue.")
		Debug("Bot resumed.")
	EndIf
	GUICtrlSetData($pauseButton, _GetPauseButtonText())
EndFunc

Func _GetPauseButtonText()
	If $paused Then Return "Resume (F9)"
	Return "Pause (F9)"
EndFunc

Func _CheckSessionLimits()
	If Not $sessionStarted Then Return

	If $maxRounds > 0 And $roundsCompleted >= $maxRounds Then
		Debug("Round limit reached. Stopping.")
		_SetStatus("Round limit reached. Bot stopped.")
		_Terminate()
	EndIf

	If $maxMinutes > 0 And TimerDiff($sessionTimer) >= $maxMinutes * 60000 Then
		Debug("Time limit reached. Stopping.")
		_SetStatus("Time limit reached. Bot stopped.")
		_Terminate()
	EndIf
EndFunc

Func _CountRound()
	If $roundCounted Then Return
	$roundCounted = 1
	$roundsCompleted += 1
	Debug("Round completed. Total: " & $roundsCompleted)
	_CheckSessionLimits()
EndFunc

Func _RefreshDashboard()
	If $guiHandle = 0 Or TimerDiff($refreshTimer) < 1000 Then Return
	$refreshTimer = TimerInit()

	Local $elapsed = 0
	If $sessionStarted Then $elapsed = Int(TimerDiff($sessionTimer) / 1000)
	Local $hours = Int($elapsed / 3600)
	Local $minutes = Mod(Int($elapsed / 60), 60)
	Local $seconds = Mod($elapsed, 60)
	GUICtrlSetData($statsLabel, StringFormat("Rounds: %d | Elapsed: %02d:%02d:%02d", $roundsCompleted, $hours, $minutes, $seconds))
EndFunc

Func _SetStatus($message)
	If $statusLabel <> 0 Then GUICtrlSetData($statusLabel, $message)
EndFunc

Func _CalibrateScreen()
	$hWnd = WinGetHandle($title)
	If $hWnd = 0 Then Return 0

	Local $size = GetClientSize($hWnd)
	If $size[0] <= 0 Or $size[1] <= 0 Then
		_SetStatus("Could not read the game window size.")
		If $lastCalibrationStatus <> "error" Then Debug("ERROR: Could not read the game client area.")
		$lastCalibrationStatus = "error"
		Return 0
	EndIf

	Local $resolution = $size[0] & "x" & $size[1]
	Switch $resolution
		Case "1280x720", "1280x800", "1440x900", "1600x900", "1920x1080", "2560x1440"
			$windowWidth = $size[0]
			$windowHeight = $size[1]
			If $lastCalibrationStatus <> $resolution Then Debug("Screen calibrated: " & $resolution)
			$lastCalibrationStatus = $resolution
			Return 1
	EndSwitch

	_SetStatus("Unsupported game client size: " & $resolution)
	If $lastCalibrationStatus <> $resolution Then Debug("ERROR: Unsupported game client size: " & $resolution)
	$lastCalibrationStatus = $resolution
	Return 0
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Game Loop

Func GameLoop()
	Debug("Game Loop")

	While WinActive($title) And $botStarted
		_ProcessControls()
		HandleAdvert()
		HandleLevelUp()
		HandleItemReceived()

		; Fault tolerant approach
		If DetectGameLost() = 1 Then
			Debug("Detect: Game Lost")
			_CountRound()
			LeaveGame()
		ElseIf DetectGetReward() = 1 Then
			; Claim participation reward
			Debug("Detect: Get Reward")
			ClickGetReward()
		ElseIf DetectGetStumbleJourneyReward() = 1 Then
			; Claim stumble journey reward (click anywhere on the screen)
			Debug("Detect: Journey Reward")
			ClickGetReward()
		ElseIf DetectGameResults() = 1 Then
			Debug("Detect: Game Results")
			_CountRound()
		ElseIf DetectGameRunning() = 1 Then
			Debug("Detect: Game Running")
			SimulateGamePlay()
			ContinueLoop
		Else
			ExitLoop
		EndIf

		_Sleep(2000)
	WEnd
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Sub Routines

Func HandleAdvert()
	; Skip the advert
	If DetectAdvert() = 1 Then
		Debug("Detect: Advert")
		ClickAdvertClose()
		_Sleep(1000)
	EndIf
EndFunc

Func HandleLevelUp()
	; Skip the stumble pass/journey level up screens
	If DetectStumblePassLevelUp() = 1 Or DetectStumbleJourneyLevelUp() = 1 Then
		Debug("Detect: Level Up")
		ClickContinue()
		_Sleep(1000)
	EndIf
EndFunc

Func HandleItemReceived()
	; Skip the item received screen
	If DetectItemReceived() = 1 Then
		Debug("Detect: Item Received")
		ClickOK()
		_Sleep(1000)
	EndIf
EndFunc

Func HandleMissionRewards()
	; Collect pending mission rewards
	If DetectMainMenuMissionComplete() = 1 Then
		Debug("Detect: Mission Complete")
		ClickMissions()
		_Sleep(1000)

		While DetectMissionReward() = 1
			Debug("Detect: Mission Reward")
			CollectMissionReward()
			_Sleep(1000)
		WEnd

		GoBack()
		_Sleep(1000)
	EndIf
EndFunc

Func HandleGameLoad()
	; not necessary but helps to determine current state
	While DetectGameSearch() = 1
		Debug("Detect: Game Search")
		If Random(0, 2) = 1 Then MouseRandom()
		_Sleep(1000, 2000)
	WEnd

	HandleScreenTransition()

	; not necessary but helps to determine current state
	While DetectMapSelection() = 1
		Debug("Detect: Map Selection")
		If Random(0, 2) = 1 Then MouseRandom()
		_Sleep(1000, 2000)
	WEnd

	; center mouse
	Mouse(Random($centerX-5, $centerX+5), Random($centerY, $centerY+10));

	; not necessary but helps to determine current state
	If DetectGameStart() = 1 Then
		While DetectGameStart() = 1
			Debug("Detect: Game Start")
			_Sleep(500)
		WEnd

		; There is a 3 second in game counter at the start of each round
		Debug("Waiting for Countdown")
		_Sleep(3000)
		Debug("Game Ready")
	EndIf
EndFunc

Func HandleScreenTransition()
	While DetectScreenTransition() = 1
		Debug("Detect: Screen Transition")
		_Sleep(1000)
	WEnd
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Detection functions

Func DetectMainMenu()
	; (Yellow Play Button)
	If IsHexColorInRange(Pixel(1871, 930), "FFC716", 10) Or IsHexColorInRange(Pixel(1941, 1026), "FFBA10", 10) Then Return 1

	Return 0
EndFunc

Func DetectMainMenuMissionComplete()
	; (Red Number Badge)
	If IsHexColorInRange(Pixel(1867, 152), "FF4B4B", 10) Or IsHexColorInRange(Pixel(1893, 181), "FF4B4B", 10) Then Return 1

	Return 0
EndFunc

Func DetectMissionReward()
	; (Full Progress Bar)
	If IsHexColorInRange(Pixel(787, 861), "FFFF94", 10) Or IsHexColorInRange(Pixel(1542, 860), "FFFF94", 10) Then Return 1

	Return 0
EndFunc

Func DetectStumbleJourneyLevelUp()
	; (White in Level Up Banner)
	Local $match1 = IsHexColorInRange(Pixel(770, 149), "FFFFFF", 10)

	; (White in Level Up Banner)
	Local $match2 = IsHexColorInRange(Pixel(1140, 164), "FFFFFF", 10)

	; (Black in Level Up Banner)
	Local $match3 = IsHexColorInRange(Pixel(1028, 155), "000000", 10)

	; (Blue in Progress Bar)
	Local $match4 = IsHexColorInRange(Pixel(664, 821), "00DBFA", 10)

	; (White in Tap To Continue Text)
	Local $match5 = IsHexColorInRange(Pixel(781, 975), "FFFFFF", 10)

	; All of them should match
	If $match1 And $match2 And $match3 And $match4 And $match5 Then Return 1

	Return 0
EndFunc

Func DetectStumblePassLevelUp()
	; (Blue Continue Button)
	Local $matchButton = IsHexColorInRange(Pixel(203, 948), "0D89EC", 10) Or IsHexColorInRange(Pixel(513, 995), "086EE7", 10)

	; (White in Banner)
	Local $matchBanner = IsHexColorInRange(Pixel(611, 117), "FFFFFF", 10) Or IsHexColorInRange(Pixel(1308, 118), "FFFFFF", 10)

	; Both of them should match
	If $matchButton And $matchBanner Then Return 1

	Return 0
EndFunc

Func DetectItemReceived()
	; (White Received Text)
	Local $match1 = IsHexColorInRange(Pixel(929, 422), "FFFFFF", 10)

	; (Purple Background)
	Local $match2 = IsHexColorInRange(Pixel(1040, 385), "7E1CB8", 10)

	; (Green Equip Now Button)
	Local $match3 = IsHexColorInRange(Pixel(610, 922), "55DB1E", 10)

	; (Blue OK Button)
	Local $match4 = IsHexColorInRange(Pixel(1601, 915), "0D88EC", 10)

	; All of them should match
	If $match1 And $match2 And $match3 And $match4 Then Return 1

	Return 0
EndFunc

Func DetectAdvert()
	; (Green bottom left purchase button)
	Local $match1 = IsHexColorInRange(Pixel(719, 919), "B1FB76", 10)

	; (Green bottom right purchase button)
	Local $match2 = IsHexColorInRange(Pixel(1167, 919), "7AB068", 10)

	; (Purple top left)
	Local $match3 = IsHexColorInRange(Pixel(335, 156), "152ED2", 10)

	; (Pink bottom right)
	Local $match4 = IsHexColorInRange(Pixel(1581, 932), "CE4F8E", 10)

	; (Red x button)
	Local $match5 = IsHexColorInRange(Pixel(1557, 103), "F45731", 10)

	; All of them should match
	If $match1 And $match2 And $match3 And $match4 And $match5 Then Return 1

	Return 0
EndFunc

Func DetectScreenTransition()
	; (Black screen)
	If IsHexColorInRange(Pixel(50, 50), "000000", 15) And _
		IsHexColorInRange(Pixel(50, 950), "000000", 15) And _
		IsHexColorInRange(Pixel(1850, 50), "000000", 15) And _
		IsHexColorInRange(Pixel(1850, 950), "000000", 15) Then
			Return 1
	EndIf

	Return 0
EndFunc

Func DetectGameSearch()
	; (Blue Abort Button)
	If IsHexColorInRange(Pixel(65, 960), "128EEB", 15) And _
		IsHexColorInRange(Pixel(331, 1020), "1586EA", 15) And _
		IsHexColorInRange(Pixel(1892, 1062), "69D8FA", 15) And _
		IsHexColorInRange(Pixel(1879, 26), "527EF1", 15) Then
			Return 1
	EndIf

	Return 0
EndFunc

Func DetectMapSelection()
	; (Purple Background)
	If IsHexColorInRange(Pixel(21, 75), "5B57CA", 20) And _
		IsHexColorInRange(Pixel(46, 1047), "8279F3", 20) And _
		IsHexColorInRange(Pixel(1847, 79), "5262D0", 20) And _
		IsHexColorInRange(Pixel(1841, 1027), "6876FF", 20) Then
			Return 1
	EndIf

	Return 0
EndFunc

Func DetectGameStart()
	; (White Screen Banner)
	If IsHexColorInRange(Pixel(672, 72), "FFFFFF", 10) And IsHexColorInRange(Pixel(1250, 52), "FFFFFF", 10) Then Return 1

	Return 0
EndFunc

Func DetectGameRunning()
	; (White Player Arrow)
	If IsHexColorInRange(Pixel(955, 446), "FFFFFF", 10) And IsHexColorInRange(Pixel(962, 446), "FFFFFF", 10) Then Return 1

	Return 0
EndFunc

Func DetectGameResults()
	; (Purple border of flying screen)
	If IsHexColorInRange(Pixel(677, 111), "531EA6", 20) And IsHexColorInRange(Pixel(1237, 109), "491993", 20) Then Return 1

	Return 0
EndFunc

Func DetectGameLost()
	; (Red Leave Button) 
	If IsHexColorInRange(Pixel(228, 969), "F7513F", 20) And IsHexColorInRange(Pixel(35, 969), "F44C39", 20) Then Return 1

	Return 0
EndFunc

Func DetectGetStumbleJourneyReward()
	; (White Congratulations Banner)
	Local $match1 = IsHexColorInRange(Pixel(611, 43), "FFFFFF", 10)

	; (White Congratulations Banner)
	Local $match2 = IsHexColorInRange(Pixel(1276, 50), "FFFFFF", 10)

	; (Black Text in Congratulations Banner)
	Local $match3 = IsHexColorInRange(Pixel(667, 71), "333333", 10)

	; (Yellow Rewards Banner)
	Local $match4 = IsHexColorInRange(Pixel(947, 130), "FFC800", 10)

	; (White Tap To Continue Text)
	Local $match5 = IsHexColorInRange(Pixel(809, 958), "FFFFFF", 10)

	; (Purple Background)
	Local $match6 = IsHexColorInRange(Pixel(946, 1004), "251852", 10)

	If $match1 And $match2 And $match3 And $match4 And $match5 And $match6 Then Return 1

	Return 0
EndFunc

Func DetectGetReward()
	; (Green Get Button)
	If IsHexColorInRange(Pixel(1499, 915), "55DB1E", 10) And IsHexColorInRange(Pixel(1809, 1001), "44D018", 10) Then Return 1

	Return 0
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Control functions 

Func GoBack()
	Debug("Go Back")
	_Send("{ESC}")
EndFunc

Func LeaveGame()
	Debug("Leave Game")
	_Send("{ESC}")
EndFunc

Func ClickMissions()
	Debug("Click Missions")
	Local $x = Random(1760, 1875)
	Local $y = Random(180, 260)
	_LeftClick($x, $y)
EndFunc

Func CollectMissionReward()
	Debug("Collect Mission Reward")
	Local $x = Random(345, 1710)
	Local $y = Random(780, 880)
	_LeftClick($x, $y)
EndFunc

Func ClickPlayGame()
	Debug("Click Play Game")
	Local $x = Random(1540, 1840)
	Local $y = Random(930, 1030)
	_LeftClick($x, $y)
EndFunc

Func ClickGetReward()
	Debug("Click Get Reward")
	Local $x = Random(1499, 1809)
	Local $y = Random(915, 1001)
	_LeftClick($x, $y)
EndFunc

Func ClickContinue()
	Debug("Click Continue")
	Local $x = Random(480, 520)
	Local $y = Random(930, 970)
	_LeftClick($x, $y)
EndFunc

Func ClickOK()
	Debug("Click OK")
	Local $x = Random(1605, 1645)
	Local $y = Random(900, 940)
	_LeftClick($x, $y)
EndFunc

Func ClickAdvertClose()
	Debug("Click Advert Close")
	Local $x = Random(1553, 1563)
	Local $y = Random(124, 134)
	_LeftClick($x, $y)
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Gameplay functions

Func SimulateGamePlay()
	Debug("Simulate Game Play")

	Local $n = 4
	Local $keys[$n] = ["Left", "Right", "Jump", "Run"]

	For $counter = 1 to $n
		If WinActive($title) = 0 Or DetectGameRunning() = 0 Or DetectGameLost() = 1 Then
			; Abort input on game loss to avoid waste of time
			Return
		EndIf

		; Start running
		_Send("{w down}")
		_Sleep(500, 1500)

		; Select random movement
		$key = Random(0, $n-1)
		Switch $keys[$key]
			Case "Left"
				$ms = Random(500, 1500)
				Left($ms)
			Case "Right"
				$ms = Random(500, 1500)
				Right($ms)
			Case "Jump"
				$ms = Random(100, 500)
				Jump($ms)
				_Sleep(500, 1000)
			Case "Run"
				_Sleep(500, 1500)
		EndSwitch

		; Stop running
		_Sleep(0, 1000)
		_Send("{w up}")

		; Short pause
		_Sleep(100, 1000)
	Next
EndFunc

Func Left($ms = 500)
	_Send("{a down}")
	_Sleep($ms)
	_Send("{a up}")
EndFunc

Func Right($ms = 500)
	_Send("{d down}")
	_Sleep($ms)
	_Send("{d up}")
EndFunc

Func Jump($ms = 500)
	_Send("{SPACE down}")
	_Sleep($ms)
	_Send("{SPACE up}")
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Mouse functions

Func Mouse($x, $y, $speed = 20)
	If WinActive($title) = 0 Then Return

	TransformCoordinates($x, $y)
	MouseMove($x, $y, $speed)

	_Sleep(50)
EndFunc

Func MouseRandom($minSpeed = 20, $maxSpeed = 30)
	If WinActive($title) = 0 Then Return

	; Try to avoid outer borders
	Local $x = Random(220, 1700)
	Local $y = Random(180, 900)
	Local $speed = Random($minSpeed, $maxSpeed)

	Mouse($x, $y, $speed)
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Color detection functions

Func Pixel($x, $y)
	TransformCoordinates($x, $y)
	Return PixelGetColor($x, $y, $hWnd)
EndFunc

Func IsHexColorInRange($color, $targetHex, $tolerance, $log = 0)
	$tolerance = Max(0, Min(255, $tolerance + $toleranceAdjustment))
	Local $sourceHex = Hex($color, 6)

	Local $sourceRGB = HexToRGB($sourceHex)
	Local $r1 = $sourceRGB[0]
	Local $g1 = $sourceRGB[1]
	Local $b1 = $sourceRGB[2]

	Local $targetRGB = HexToRGB($targetHex)
	Local $r2 = $targetRGB[0]
	Local $g2 = $targetRGB[1]
	Local $b2 = $targetRGB[2]
	
	Local $isColorInRange = _
		Abs($r1 - $r2) <= $tolerance And _
		Abs($g1 - $g2) <= $tolerance And _
		Abs($b1 - $b2) <= $tolerance

	If $log = 1 And $isColorInRange = 0 Then
		Debug("Detected: " & $sourceHex & " / Wanted: " & $targetHex)
		Debug("Diff R: " & Abs($r1 - $r2) & ", G: " & Abs($g1 - $g2) & ", B: " & Abs($b1 - $b2))
		_Sleep(500)
	EndIf

	Return $isColorInRange
EndFunc

Func HexToRGB($hex)
	Local $r = Dec(StringLeft($hex, 2))
	Local $g = Dec(StringMid($hex, 3, 2))
	Local $b = Dec(StringRight($hex, 2))
	Local $rgb[3] = [$r, $g, $b]
	Return $rgb
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Transform functions to support different screen resolutions

Func TransformCoordinates(ByRef $x, ByRef $y)
	If $windowWidth <> $baseWidth Or $windowHeight <> $baseHeight Then
		$x = Round($x * $windowWidth / $baseWidth)
		$y = Round($y * $windowHeight / $baseHeight)
	EndIf
EndFunc

Func GetClientSize($hWnd)
	Local $r = DllStructCreate("int Left; int Top; int Right; int Bottom")
	Local $call = DllCall("user32.dll", "bool", "GetClientRect", "hwnd", $hWnd, "ptr", DllStructGetPtr($r))
	Local $size[2]
	If @error Or Not IsArray($call) Or $call[0] = 0 Then
		$size[0] = 0
		$size[1] = 0
		Return $size
	EndIf
	$size[0] = DllStructGetData($r, "Right") - DllStructGetData($r, "Left")
	$size[1] = DllStructGetData($r, "Bottom") - DllStructGetData($r, "Top")
	Return $size
EndFunc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Simple wrapper functions

Func _Send($keys, $flag = 0)
	If WinActive($title) = 0 Then Return

	Send($keys, $flag)
EndFunc

Func _LeftClick($x, $y)
	If WinActive($title) = 0 Then Return

	TransformCoordinates($x, $y)
	MouseClick("left", $x, $y, 1, 10)

	_Sleep(100)
EndFunc

Func _Sleep($min, $max = -1)
	Local $remaining = $min
	If $max > 0 Then
		$remaining = Random($min, $max)
	EndIf

	While $remaining > 0
		_ProcessControls()
		If $paused Then
			Sleep(100)
		Else
			Local $chunk = Min(100, $remaining)
			Sleep($chunk)
			$remaining -= $chunk
		EndIf
	EndIf
EndFunc

Func _Terminate()
	Exit
EndFunc

Func _ReleaseKeys()
	If $hWnd = 0 Then Return
	If WinActive($title) Then
		Send("{w up}{a up}{d up}{SPACE up}")
	Else
		Local $result = ControlSend($hWnd, "", "", "{w up}{a up}{d up}{SPACE up}")
		If @error Or $result = 0 Then Debug("WARNING: Could not release movement keys through the inactive game window.")
	EndIf
EndFunc

Func _Cleanup()
	_ReleaseKeys()
	If $sessionStarted Then
		Local $elapsed = Int(TimerDiff($sessionTimer) / 1000)
		Debug("Session summary: " & $roundsCompleted & " rounds, " & $elapsed & " seconds.")
	EndIf
	If $logHandle <> -1 Then FileClose($logHandle)
	If $guiHandle <> 0 Then GUIDelete($guiHandle)
EndFunc

Func Debug($msg)
	If $logHandle <> -1 Then
		Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
		FileWriteLine($logHandle, $timestamp & " " & $msg)
	EndIf
	If Not @Compiled Then
		ConsoleWrite($msg & @CRLF)
	EndIf
EndFunc
