-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/rule.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
-- @flow
local buildCommon = require(script.Parent.Parent.buildCommon).default
local defineFunction = require(script.Parent.Parent.defineFunction).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local unitsModule = require(script.Parent.Parent.units)
local calculateSize = unitsModule.calculateSize
local makeEm = unitsModule.makeEm
defineFunction({
	type = "rule",
	names = { "\\rule" },
	props = { numArgs = 2, numOptionalArgs = 1, argTypes = { "size", "size", "size" } },
	handler = function(self, ref0, args, optArgs)
		local parser = ref0.parser
		local shift = optArgs[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local width = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"size"
		)
		local height = assertNodeType(
			args[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"size"
		)
		return {
			type = "rule",
			mode = parser.mode,
			shift = if Boolean.toJSBoolean(shift)
				then assertNodeType(shift, "size").value
				else shift,
			width = width.value,
			height = height.value,
		}
	end,
	htmlBuilder = function(self, group, options)
		-- Make an empty span for the rule
		local rule = buildCommon:makeSpan({ "mord", "rule" }, {}, options) -- Calculate the shift, width, and height of the rule, and account for units
		local width = calculateSize(group.width, options)
		local height = calculateSize(group.height, options)
		local shift = if Boolean.toJSBoolean(group.shift)
			then calculateSize(group.shift, options)
			else 0 -- Style the rule to the right size
		rule.style.borderRightWidth = makeEm(width)
		rule.style.borderTopWidth = makeEm(height)
		rule.style.bottom = makeEm(shift) -- Record the height and width
		rule.width = width
		rule.height = height + shift
		rule.depth = -shift -- Font size is the number large enough that the browser will
		-- reserve at least `absHeight` space above the baseline.
		-- The 1.125 factor was empirically determined
		rule.maxFontSize = height * 1.125 * options.sizeMultiplier
		return rule
	end,
	mathmlBuilder = function(self, group, options)
		local width = calculateSize(group.width, options)
		local height = calculateSize(group.height, options)
		local shift = if Boolean.toJSBoolean(group.shift)
			then calculateSize(group.shift, options)
			else 0
		local ref = if Boolean.toJSBoolean(options.color) then options:getColor() else options.color
		local color = Boolean.toJSBoolean(ref) and ref or "black"
		local rule = mathMLTree.MathNode.new("mspace")
		rule:setAttribute("mathbackground", color)
		rule:setAttribute("width", makeEm(width))
		rule:setAttribute("height", makeEm(height))
		local wrapper = mathMLTree.MathNode.new("mpadded", { rule })
		if
			shift
			>= 0 --[[ ROBLOX CHECK: operator '>=' works only if either both arguments are strings or both are a number ]]
		then
			wrapper:setAttribute("height", makeEm(shift))
		else
			wrapper:setAttribute("height", makeEm(shift))
			wrapper:setAttribute("depth", makeEm(-shift))
		end
		wrapper:setAttribute("voffset", makeEm(shift))
		return wrapper
	end,
})
