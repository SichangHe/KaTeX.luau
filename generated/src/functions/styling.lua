-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/styling.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local Style = require(script.Parent.Parent.Style).default
local sizingGroup = require(script.Parent.sizing).sizingGroup
local mml = require(script.Parent.Parent.buildMathML)
local styleMap = {
	["display"] = Style.DISPLAY,
	["text"] = Style.TEXT,
	["script"] = Style.SCRIPT,
	["scriptscript"] = Style.SCRIPTSCRIPT,
}
defineFunction({
	type = "styling",
	names = { "\\displaystyle", "\\textstyle", "\\scriptstyle", "\\scriptscriptstyle" },
	props = { numArgs = 0, allowedInText = true, primitive = true },
	handler = function(self, ref0, args)
		local breakOnTokenText, funcName, parser = ref0.breakOnTokenText, ref0.funcName, ref0.parser
		-- parse out the implicit body
		local body = parser:parseExpression(true, breakOnTokenText) -- TODO: Refactor to avoid duplicating styleMap in multiple places (e.g.
		-- here and in buildHTML and de-dupe the enumeration of all the styles).
		-- $FlowFixMe: The names above exactly match the styles.
		local style: StyleStr = Array.slice(funcName, 1, funcName.length - 5) --[[ ROBLOX CHECK: check if 'funcName' is an Array ]]
		return {
			type = "styling",
			mode = parser.mode,
			-- Figure out what style to use by pulling out the style from
			-- the function name
			style = style,
			body = body,
		}
	end,
	htmlBuilder = function(self, group, options)
		-- Style changes are handled in the TeXbook on pg. 442, Rule 3.
		local newStyle = styleMap[tostring(group.style)]
		local newOptions = options:havingStyle(newStyle):withFont("")
		return sizingGroup(group.body, newOptions, options)
	end,
	mathmlBuilder = function(self, group, options)
		-- Figure out what style we're changing to.
		local newStyle = styleMap[tostring(group.style)]
		local newOptions = options:havingStyle(newStyle)
		local inner = mml:buildExpression(group.body, newOptions)
		local node = mathMLTree.MathNode.new("mstyle", inner)
		local styleAttributes = {
			["display"] = { "0", "true" },
			["text"] = { "0", "false" },
			["script"] = { "1", "false" },
			["scriptscript"] = { "2", "false" },
		}
		local attr = styleAttributes[tostring(group.style)]
		node:setAttribute(
			"scriptlevel",
			attr[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
		)
		node:setAttribute(
			"displaystyle",
			attr[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
		)
		return node
	end,
})
