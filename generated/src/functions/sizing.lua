-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/sizing.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local exports = {}
-- @flow
local buildCommon = require(script.Parent.Parent.buildCommon).default
local defineFunction = require(script.Parent.Parent.defineFunction).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local makeEm = require(script.Parent.Parent.units).makeEm
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local optionsModule = require(script.Parent.Parent.Options)
type Options = optionsModule.default
local parseNodeModule = require(script.Parent.Parent.parseNode)
type AnyParseNode = parseNodeModule.AnyParseNode
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type HtmlBuilder = defineFunctionModule.HtmlBuilder
local domTreeModule = require(script.Parent.Parent.domTree)
type HtmlDocumentFragment = domTreeModule.documentFragment
local function sizingGroup(
	value: any --[[ ROBLOX TODO: Unhandled node for type: ArrayTypeAnnotation ]] --[[ AnyParseNode[] ]],
	options: Options,
	baseOptions: Options
): HtmlDocumentFragment
	local inner = html:buildExpression(value, options, false)
	local multiplier = options.sizeMultiplier / baseOptions.sizeMultiplier -- Add size-resetting classes to the inner list and set maxFontSize
	-- manually. Handle nested size changes.
	do
		local i = 0
		while
			i
			< inner.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local pos = Array.indexOf(inner[tostring(i)].classes, "sizing") --[[ ROBLOX CHECK: check if 'inner[i].classes' is an Array ]]
			if
				pos
				< 0 --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then
				Array.concat(inner[tostring(i)].classes, options:sizingClasses(baseOptions)) --[[ ROBLOX CHECK: check if 'Array.prototype' is an Array ]]
			elseif
				inner[tostring(i)].classes[tostring(pos + 1)]
				== ("reset-size" .. tostring(options.size))
			then
				-- This is a nested size change: e.g., inner[i] is the "b" in
				-- `\Huge a \small b`. Override the old size (the `reset-` class)
				-- but not the new size.
				inner[tostring(i)].classes[tostring(pos + 1)] = "reset-size"
					.. tostring(baseOptions.size)
			end
			inner[tostring(i)].height *= multiplier
			inner[tostring(i)].depth *= multiplier
			i += 1
		end
	end
	return buildCommon:makeFragment(inner)
end
exports.sizingGroup = sizingGroup
local sizeFuncs = {
	"\\tiny",
	"\\sixptsize",
	"\\scriptsize",
	"\\footnotesize",
	"\\small",
	"\\normalsize",
	"\\large",
	"\\Large",
	"\\LARGE",
	"\\huge",
	"\\Huge",
}
local htmlBuilder: HtmlBuilder<"sizing">
function htmlBuilder(group, options)
	-- Handle sizing operators like \Huge. Real TeX doesn't actually allow
	-- these functions inside of math expressions, so we do some special
	-- handling.
	local newOptions = options:havingSize(group.size)
	return sizingGroup(group.body, newOptions, options)
end
exports.htmlBuilder = htmlBuilder
defineFunction({
	type = "sizing",
	names = sizeFuncs,
	props = { numArgs = 0, allowedInText = true },
	handler = function(ref0, args)
		local breakOnTokenText, funcName, parser = ref0.breakOnTokenText, ref0.funcName, ref0.parser
		local body = parser:parseExpression(false, breakOnTokenText)
		return {
			type = "sizing",
			mode = parser.mode,
			-- Figure out what size to use based on the list of functions above
			size = Array.indexOf(sizeFuncs, funcName) --[[ ROBLOX CHECK: check if 'sizeFuncs' is an Array ]]
				+ 1,
			body = body,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = function(group, options)
		local newOptions = options:havingSize(group.size)
		local inner = mml:buildExpression(group.body, newOptions)
		local node = mathMLTree.MathNode.new("mstyle", inner) -- TODO(emily): This doesn't produce the correct size for nested size
		-- changes, because we don't keep state of what style we're currently
		-- in, so we can't reset the size to normal before changing it.  Now
		-- that we're passing an options parameter we should be able to fix
		-- this.
		node:setAttribute("mathsize", makeEm(newOptions.sizeMultiplier))
		return node
	end,
})
return exports
