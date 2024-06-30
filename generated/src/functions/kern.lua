-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/kern.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
--@flow
-- Horizontal spacing commands
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local calculateSize = require(script.Parent.Parent.units).calculateSize
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType -- TODO: \hskip and \mskip should support plus and minus in lengths
defineFunction({
	type = "kern",
	names = { "\\kern", "\\mkern", "\\hskip", "\\mskip" },
	props = { numArgs = 1, argTypes = { "size" }, primitive = true, allowedInText = true },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local size = assertNodeType(
			args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
			"size"
		)
		if Boolean.toJSBoolean(parser.settings.strict) then
			local mathFunction = funcName[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			] == "m" -- \mkern, \mskip
			local muUnit = size.value.unit == "mu"
			if Boolean.toJSBoolean(mathFunction) then
				if not Boolean.toJSBoolean(muUnit) then
					parser.settings:reportNonstrict(
						"mathVsTextUnits",
						("LaTeX's %s supports only mu units, "):format(tostring(funcName))
							.. ("not %s units"):format(tostring(size.value.unit))
					)
				end
				if parser.mode ~= "math" then
					parser.settings:reportNonstrict(
						"mathVsTextUnits",
						("LaTeX's %s works only in math mode"):format(tostring(funcName))
					)
				end
			else
				-- !mathFunction
				if Boolean.toJSBoolean(muUnit) then
					parser.settings:reportNonstrict(
						"mathVsTextUnits",
						("LaTeX's %s doesn't support mu units"):format(tostring(funcName))
					)
				end
			end
		end
		return { type = "kern", mode = parser.mode, dimension = size.value }
	end,
	htmlBuilder = function(self, group, options)
		return buildCommon:makeGlue(group.dimension, options)
	end,
	mathmlBuilder = function(self, group, options)
		local dimension = calculateSize(group.dimension, options)
		return mathMLTree.SpaceNode.new(dimension)
	end,
})
