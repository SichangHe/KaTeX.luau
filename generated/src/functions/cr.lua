-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/cr.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
--@flow
-- Row breaks within tabular environments, and line breaks at top level
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local unitsModule = require(script.Parent.Parent.units)
local calculateSize = unitsModule.calculateSize
local makeEm = unitsModule.makeEm
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType -- \DeclareRobustCommand\\{...\@xnewline}
defineFunction({
	type = "cr",
	names = { "\\\\" },
	props = { numArgs = 0, numOptionalArgs = 0, allowedInText = true },
	handler = function(self, ref0, args, optArgs)
		local parser = ref0.parser
		local size = if parser.gullet:future().text == "[" then parser:parseSizeGroup(true) else nil
		local newLine = not Boolean.toJSBoolean(parser.settings.displayMode)
			or not Boolean.toJSBoolean(
				parser.settings:useStrictBehavior(
					"newLineInDisplayMode",
					"In LaTeX, \\\\ or \\newline " .. "does nothing in display mode"
				)
			)
		return {
			type = "cr",
			mode = parser.mode,
			newLine = newLine,
			size = if Boolean.toJSBoolean(size) then assertNodeType(size, "size").value else size,
		}
	end,
	-- The following builders are called only at the top level,
	-- not within tabular/array environments.
	htmlBuilder = function(self, group, options)
		local span = buildCommon:makeSpan({ "mspace" }, {}, options)
		if Boolean.toJSBoolean(group.newLine) then
			table.insert(span.classes, "newline") --[[ ROBLOX CHECK: check if 'span.classes' is an Array ]]
			if Boolean.toJSBoolean(group.size) then
				span.style.marginTop = makeEm(calculateSize(group.size, options))
			end
		end
		return span
	end,
	mathmlBuilder = function(self, group, options)
		local node = mathMLTree.MathNode.new("mspace")
		if Boolean.toJSBoolean(group.newLine) then
			node:setAttribute("linebreak", "newline")
			if Boolean.toJSBoolean(group.size) then
				node:setAttribute("height", makeEm(calculateSize(group.size, options)))
			end
		end
		return node
	end,
})
