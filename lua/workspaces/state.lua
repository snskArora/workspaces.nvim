-- Runtime state shared by every module. Always read fields through this table
-- (e.g. `state.folders`) rather than caching them: loading a workspace
-- replaces `folders` with a new table.
return {
	folders = {}, -- absolute paths with a trailing "/"
	active = nil, -- name of the currently loaded workspace session
}
