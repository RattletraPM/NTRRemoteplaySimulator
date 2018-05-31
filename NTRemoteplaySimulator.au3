#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.2
 Author:         RattletraPM

 Script Function:
	Script that simulates NTR CFW's Remoteplay feature.

	It is not an "emulator" because it doesn't try to run NTR's own code on a PC,
	,nstead it tries to mimic NTR's behaivor as accurately as possible.

	NOTE: This script outputs to stdout instead of a GUI!

#ce ----------------------------------------------------------------------------
#include <Misc.au3>
#include <File.au3>
#include <Array.au3>

Opt("TrayAutoPause",0)

Global $sIPAddress="127.0.0.1" ; Listen IP
Global $iPort=8000 ; Listen port, don't change this unless you know what you're doing!
Const $sJpgExt="*.jpg"
Global $aTopImgs=_FileListToArray("top",$sJpgExt,1,True)
Global $aBotImgs=_FileListToArray("bot",$sJpgExt,1,True)
Global $iFrameID=1

ConsoleWrite("NTRemoteplaySimulator vWhatever by RattletraPM"&@CRLF&@CRLF&"Listening on "&$sIPAddress&":"&$iPort&@CRLF)
If IsArray($aTopImgs)<>1 Then ConsoleWrite("WARNING: No images have been found for the top screen!"&@CRLF)
If IsArray($aBotImgs)<>1 Then ConsoleWrite("WARNING: No images have been found for the bottom screen!"&@CRLF)
WaitRemoteplayCmd()
SendJPEG()

Func StreamFrame($sFname,$iSocket,$iIsTop)
	Local $iFSize=FileGetSize($sFname)
	Local $hFile=FileOpen($sFname,16)
	Local $iFrameNum=0
	Local $iLast=0
	While $iLast<>1
		Local $dRead=StringTrimLeft(FileRead($hFile,1444),2)	;1448
		If $iFSize<=1444*($iFrameNum+1) Then $iLast=1
		UDPSend($iSocket,Binary("0x"&Hex($iFrameID,2)&$iLast&$iIsTop&"02"&Hex($iFrameNum,2)&$dRead))
		$iFrameNum+=1
	WEnd
	If $iFrameID<255 Then
		$iFrameID+=1
	Else
		$iFrameID=0
	EndIf
	FileClose($hFile)
	Sleep(15)
EndFunc

Func SendJPEG()
	UDPStartup()
	Local $iUDPSocket=UDPOpen($sIPAddress, $iPort+1)
	Local $iTopIndex=1
	Local $iBotIndex=1
	Local $bTopStreamed=False
	While 1
		If IsArray($aTopImgs) And $bTopStreamed==False Then
			StreamFrame($aTopImgs[$iTopIndex],$iUDPSocket,1)
			If $iTopIndex<$aTopImgs[0] Then
				$iTopIndex+=1
			Else
				$iTopIndex=1
			EndIf
			$bTopStreamed=True
		ElseIf IsArray($aBotImgs) And $bTopStreamed==True Then
			StreamFrame($aBotImgs[$iBotIndex],$iUDPSocket,0)
			If $iBotIndex<$aBotImgs[0] Then
				$iBotIndex+=1
			Else
				$iBotIndex=1
			EndIf
			$bTopStreamed=False
		Else
			If IsArray($aTopImgs) Then $bTopStreamed=False
			If IsArray($aBotImgs) Then $bTopStreamed=True
		EndIf
	WEnd
EndFunc

Func WaitRemoteplayCmd()
	TCPStartup()

	Local $iSocket=-1,$sHDR="",$sCMD="",$sReceived="",$bIsNTRdbg=False

	Local $iListenSocket = TCPListen($sIPAddress, $iPort, 100)

	If @error Then
	   ConsoleWrite("TCPListen failed! @error="&@error&@CRLF)
	   Exit
	EndIf

	While 1
	   If $iSocket<=0 Then	;If you're unsure why sometimes the socket id mustn't be reset, check the comments below
		   $iSocket=TCPAccept($iListenSocket)
		EndIf

		If @error Then
			$iError = @error
			ConsoleWrite("TCPAccept failed! @error="&@error&@CRLF)
		EndIf
		If $iSocket>0 Then
			$sReceived=TCPRecv($iSocket, 14, 1)
			$sHDR=StringLeft($sReceived,10)

			; Here's the comment you were looking for! (If not, there's nothing interesting here for you)
			; The reason why the socket id sometimes must not be reset is because Snickerstream and NTRDebugger act in
			; different ways:
			;
			; - NTRDebugger uses a single socket for each and every command, disconnecting only if the command requires it
			; or if the user explicitly says to (useful if you expect multiple commands to be sent in the same session,
			; like when actually debugging stuff on the console)
			;
			; - Snickerstream sends a single command and then disconnects (because the user should only need to send one
			; or two commands on each use - usually just remoteplay, which expects the connection to be closed as soon
			; as it's sent)
			;
			; Luckily there is a way to know which one of the two connected to the server: NTRDebugger sends a command
			; with CommandID 0000 right after connecting while Snickerstream does not, so if we get said command we know
			; that we should keep listening to the same socket id!
			If $sHDR=="0x78563412" Then
				$sCMD=StringRight($sReceived,4)
				ConsoleWrite("Command received - CMD: "&$sCMD&", ")
				Switch $sCMD
					Case "0000"
						ConsoleWrite("NTRDebugger connected."&@CRLF)
						$bIsNTRdbg=True
					Case "8503"
						ConsoleWrite("Starting remoteplay on UDP port "&$iPort+1&"!"&@CRLF)
						TCPCloseSocket($iSocket)
						If $bIsNTRdbg==False Then
							Do
								$iSocket=TCPAccept($iListenSocket)
								$sReceived=TCPRecv($iSocket, 14, 1)
							Until $iSocket>0
						EndIf
						ExitLoop
					Case "0300"
						ConsoleWrite("Oh hey there!"&@CRLF)
					Case Else
						ConsoleWrite("Unknown command"&@CRLF)
						TCPCloseSocket($iSocket)
						$iSocket=-1
				EndSwitch
			EndIf
		EndIf
	WEnd

	TCPCloseSocket($iSocket)
	TCPCloseSocket($iListenSocket)
	TCPShutdown() ; Close the TCP service.
EndFunc