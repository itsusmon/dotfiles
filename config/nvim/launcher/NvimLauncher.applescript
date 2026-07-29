use scripting additions

property ghosttyBundleIdentifier : "com.mitchellh.ghostty"

on run
	try
		launchNeovim({})
	on error errorMessage number errorNumber
		showLaunchError(errorMessage, errorNumber)
	end try
end run

on open openedItems
	try
		launchNeovim(openedItems)
	on error errorMessage number errorNumber
		showLaunchError(errorMessage, errorNumber)
	end try
end open

on closeRequestedSurface(locationText)
	set closePrefix to "nvim-launcher://close/"
	if locationText does not start with closePrefix then error "Nvim received an invalid cleanup request."
	set closeToken to text ((count of closePrefix) + 1) thru -1 of locationText
	set helperPath to POSIX path of (path to me) & "Contents/Resources/nvim-launcher-helper"
	set closeFields to tabFields(runHelper(helperPath, {"consume-close", closeToken}))
	if (count of closeFields) is not 4 or item 1 of closeFields is not "CLOSE" then
		error "Nvim could not validate the cleanup request."
	end if
	closeTerminal(item 2 of closeFields, item 3 of closeFields, item 4 of closeFields)
end closeRequestedSurface

on launchNeovim(openedItems)
	set ghosttyPath to discoverGhostty()
	verifyGhostty(ghosttyPath)
	set nvimPath to resolveNeovim()
	set helperPath to POSIX path of (path to me) & "Contents/Resources/nvim-launcher-helper"
	set openedPaths to {}

	repeat with openedItem in openedItems
		set end of openedPaths to POSIX path of openedItem
	end repeat

	if (count of openedPaths) is 0 then
		set cwdPath to (system attribute "HOME") & "/"
		launchOneShot(helperPath, nvimPath, {}, cwdPath)
		return
	end if
	if (count of openedPaths) is 1 and isDirectory(item 1 of openedPaths) then
		launchRooted(helperPath, nvimPath, item 1 of openedPaths)
		return
	end if

	set routeOutput to runHelper(helperPath, {"route", nvimPath} & openedPaths)
	set unmatchedIndexes to handleRouteOutput(routeOutput)
	if (count of unmatchedIndexes) is 0 then return

	set unmatchedPaths to {}
	repeat with unmatchedIndex in unmatchedIndexes
		set end of unmatchedPaths to item ((unmatchedIndex as integer) + 1) of openedPaths
	end repeat
	set cwdPath to parentDirectory(item 1 of unmatchedPaths)
	launchOneShot(helperPath, nvimPath, unmatchedPaths, cwdPath)
end launchNeovim

on launchRooted(helperPath, nvimPath, rootPath)
	set reservationOutput to runHelper(helperPath, {"reserve", nvimPath, rootPath})
	if reservationOutput starts with "FOCUS" then
		handleRouteOutput(reservationOutput)
		return
	end if
	if reservationOutput starts with "QUEUED" then return

	set reservationFields to tabFields(reservationOutput)
	if (count of reservationFields) is not 3 or item 1 of reservationFields is not "NEW" then
		error "The launcher could not reserve the Neovim project root."
	end if
	set rootHash to item 2 of reservationFields
	set sessionToken to item 3 of reservationFields

	try
		set surfaceCommand to helperCommand(helperPath, {"run-root", rootHash, sessionToken})
		set surfaceIdentity to createSurface(surfaceCommand, rootPath)
	on error errorMessage number errorNumber
		try
			runHelper(helperPath, {"cancel", rootHash, sessionToken})
		end try
		error errorMessage number errorNumber
	end try

	set publishOutput to runHelper(helperPath, {"publish", rootHash, sessionToken, item 1 of surfaceIdentity, item 2 of surfaceIdentity, item 3 of surfaceIdentity})
	if publishOutput is not "READY" then
		error "Neovim started, but its launcher session could not be verified."
	end if
end launchRooted

on launchOneShot(helperPath, nvimPath, openedPaths, cwdPath)
	set reservationOutput to runHelper(helperPath, {"prepare-once", nvimPath} & openedPaths)
	set reservationFields to tabFields(reservationOutput)
	if (count of reservationFields) is not 3 or item 1 of reservationFields is not "NEW" then
		error "The launcher could not prepare the Neovim process."
	end if
	set launchHash to item 2 of reservationFields
	set launchToken to item 3 of reservationFields

	try
		set surfaceCommand to helperCommand(helperPath, {"run-once", launchHash, launchToken})
		set surfaceIdentity to createSurface(surfaceCommand, cwdPath)
	on error errorMessage number errorNumber
		try
			runHelper(helperPath, {"cancel", launchHash, launchToken})
		end try
		error errorMessage number errorNumber
	end try

	set publishOutput to runHelper(helperPath, {"publish-once", launchHash, launchToken, item 1 of surfaceIdentity, item 2 of surfaceIdentity, item 3 of surfaceIdentity})
	if publishOutput is not "READY" then
		error "Neovim started, but its terminal lifetime could not be verified."
	end if
end launchOneShot

on handleRouteOutput(routeOutput)
	set unmatchedIndexes to {}
	if routeOutput is "" then return unmatchedIndexes

	repeat with outputLine in paragraphs of routeOutput
		set outputFields to tabFields(outputLine as text)
		if (count of outputFields) > 0 then
			set recordType to item 1 of outputFields
			if recordType is "FOCUS" and (count of outputFields) is 4 then
				set focused to focusTerminal(item 2 of outputFields, item 3 of outputFields, item 4 of outputFields)
				if not focused then
					using terms from application "Ghostty"
						tell application id "com.mitchellh.ghostty" to activate
					end using terms from
					display notification "The file opened through Neovim RPC, but its exact Ghostty tab is no longer available." with title "Nvim"
				end if
			else if recordType is "UNMATCHED" and (count of outputFields) is 2 then
				set end of unmatchedIndexes to (item 2 of outputFields) as integer
			end if
		end if
	end repeat
	return unmatchedIndexes
end handleRouteOutput

on createSurface(surfaceCommand, cwdPath)
	try
		using terms from application "Ghostty"
			tell application id "com.mitchellh.ghostty"
				set surfaceConfiguration to new surface configuration
				set initial working directory of surfaceConfiguration to cwdPath
				set command of surfaceConfiguration to surfaceCommand
				set wait after command of surfaceConfiguration to false

				if (count of windows) is 0 then
					set createdWindow to new window with configuration surfaceConfiguration
					set createdTab to selected tab of createdWindow
				else
					set createdWindow to front window
					set createdTab to new tab in createdWindow with configuration surfaceConfiguration
					select tab createdTab
				end if

				set createdTerminal to focused terminal of createdTab
				focus createdTerminal
				activate window createdWindow
				activate
				return {(id of createdWindow) as text, (id of createdTab) as text, (id of createdTerminal) as text}
			end tell
		end using terms from
	on error errorMessage number errorNumber
		error "Ghostty could not create the Neovim terminal. Ensure Ghostty 1.3 or newer is installed and macos-applescript is not set to false. " & errorMessage number errorNumber
	end try
end createSurface

on focusTerminal(windowID, tabID, terminalID)
	using terms from application "Ghostty"
		tell application id "com.mitchellh.ghostty"
			repeat with candidateWindow in windows
				if ((id of candidateWindow) as text) is windowID then
					repeat with candidateTab in tabs of candidateWindow
						if ((id of candidateTab) as text) is tabID then
							repeat with candidateTerminal in terminals of candidateTab
								if ((id of candidateTerminal) as text) is terminalID then
									select tab candidateTab
									focus candidateTerminal
									activate window candidateWindow
									activate
									return true
								end if
							end repeat
						end if
					end repeat
				end if
			end repeat
		end tell
	end using terms from
	return false
end focusTerminal

on closeTerminal(windowID, tabID, terminalID)
	using terms from application "Ghostty"
		tell application id "com.mitchellh.ghostty"
			repeat with candidateWindow in windows
				if ((id of candidateWindow) as text) is windowID then
					repeat with candidateTab in tabs of candidateWindow
						if ((id of candidateTab) as text) is tabID then
							repeat with candidateTerminal in terminals of candidateTab
								if ((id of candidateTerminal) as text) is terminalID then
									close candidateTerminal
									return true
								end if
							end repeat
						end if
					end repeat
				end if
			end repeat
		end tell
	end using terms from
	return false
end closeTerminal

on runHelper(helperPath, arguments)
	return do shell script helperCommand(helperPath, arguments)
end runHelper

on helperCommand(helperPath, arguments)
	set commandText to quoted form of helperPath
	repeat with argumentValue in arguments
		set commandText to commandText & " " & quoted form of (argumentValue as text)
	end repeat
	return commandText
end helperCommand

on tabFields(inputText)
	set previousDelimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to tab
	set fields to text items of inputText
	set AppleScript's text item delimiters to previousDelimiters
	return fields
end tabFields

on parentDirectory(candidatePath)
	if isDirectory(candidatePath) then return candidatePath
	return do shell script "/usr/bin/dirname -- " & quoted form of candidatePath
end parentDirectory

on discoverGhostty()
	try
		set registeredGhostty to path to application id ghosttyBundleIdentifier
		set registeredPath to POSIX path of registeredGhostty
		if isDirectory(registeredPath) then return registeredPath
	end try

	set homeDirectory to (system attribute "HOME") & "/"
	repeat with candidatePath in {"/Applications/Ghostty.app", homeDirectory & "Applications/Ghostty.app"}
		if isDirectory(candidatePath as text) then return candidatePath as text
	end repeat

	error "Ghostty was not found. Install Ghostty 1.3 or newer in /Applications or ~/Applications, then run the dotfiles installer again."
end discoverGhostty

on verifyGhostty(ghosttyPath)
	set requiredCommands to {"<command name=\"new surface configuration\"", "<command name=\"new window\"", "<command name=\"new tab\"", "<command name=\"select tab\"", "<command name=\"focus\"", "<command name=\"close\"", "<command name=\"activate window\"", "<property name=\"id\"", "<property name=\"initial working directory\"", "<property name=\"command\"", "<property name=\"wait after command\""}

	try
		set scriptingDefinition to do shell script "/usr/bin/sdef " & quoted form of ghosttyPath
	on error
		error "Ghostty's AppleScript dictionary could not be read. Install Ghostty 1.3 or newer and ensure macos-applescript is not set to false."
	end try

	repeat with requiredCommand in requiredCommands
		if scriptingDefinition does not contain (requiredCommand as text) then
			error "This Ghostty installation does not expose the required AppleScript commands. Upgrade to Ghostty 1.3 or newer and ensure macos-applescript is not set to false."
		end if
	end repeat
end verifyGhostty

on resolveNeovim()
	set homeDirectory to (system attribute "HOME") & "/"
	set candidates to {"/opt/homebrew/bin/nvim", "/usr/local/bin/nvim", "/usr/bin/nvim", homeDirectory & ".local/bin/nvim"}

	repeat with candidatePath in candidates
		if isExecutable(candidatePath as text) then return candidatePath as text
	end repeat

	set loginShell to system attribute "SHELL"
	if loginShell is "" then set loginShell to "/bin/zsh"

	if isExecutable(loginShell) then
		try
			set resolvedPath to do shell script quoted form of loginShell & " -l -c " & quoted form of "command -v nvim"
			if resolvedPath starts with "/" and resolvedPath does not contain linefeed and isExecutable(resolvedPath) then return resolvedPath
		end try
	end if

	error "Neovim was not found. Install nvim in /opt/homebrew/bin, /usr/local/bin, /usr/bin, ~/.local/bin, or make it available to your login shell."
end resolveNeovim

on isExecutable(candidatePath)
	try
		do shell script "/bin/test -x " & quoted form of candidatePath
		return true
	on error
		return false
	end try
end isExecutable

on isDirectory(candidatePath)
	try
		do shell script "/bin/test -d " & quoted form of candidatePath
		return true
	on error
		return false
	end try
end isDirectory

on showLaunchError(errorMessage, errorNumber)
	display alert "Nvim could not open the file" message errorMessage & return & return & "Error " & errorNumber as critical
end showLaunchError

on showCleanupError(errorMessage)
	display notification (errorMessage as text) with title "Nvim surface cleanup failed"
end showCleanupError

on «event GURLGURL» locationText
	try
		closeRequestedSurface(locationText)
	on error errorMessage
		showCleanupError(errorMessage)
	end try
end «event GURLGURL»
