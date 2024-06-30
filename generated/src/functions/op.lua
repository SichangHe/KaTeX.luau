-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/op.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local instanceof = LuauPolyfill.instanceof
local exports = {}
-- @flow
-- Limits, symbols
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local SymbolNode = require(script.Parent.Parent.domTree).SymbolNode
local mathMLTree = require(script.Parent.Parent.mathMLTree)
local utils = require(script.Parent.Parent.utils).default
local Style = require(script.Parent.Parent.Style).default
local assembleSupSub = require(script.Parent.utils.assembleSupSub).assembleSupSub
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local makeEm = require(script.Parent.Parent.units).makeEm
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type HtmlBuilderSupSub = defineFunctionModule.HtmlBuilderSupSub
type MathMLBuilder = defineFunctionModule.MathMLBuilder
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode -- Most operators have a large successor symbol, but these don't.
local noSuccessor = { "\\smallint" } -- NOTE: Unlike most `htmlBuilder`s, this one handles not only "op", but also
-- "supsub" since some of them (like \int) can affect super/subscripting.
local htmlBuilder: HtmlBuilderSupSub<"op">
function htmlBuilder(grp, options)
	-- Operators are handled in the TeXbook pg. 443-444, rule 13(a).
	local supGroup
	local subGroup
	local hasLimits = false
	local group: ParseNode<"op">
	if grp.type == "supsub" then
		-- If we have limits, supsub will pass us its group to handle. Pull
		-- out the superscript and subscript and set the group to the op in
		-- its base.
		supGroup = grp.sup
		subGroup = grp.sub
		group = assertNodeType(grp.base, "op")
		hasLimits = true
	else
		group = assertNodeType(grp, "op")
	end
	local style = options.style
	local large = false
	if
		Boolean.toJSBoolean((function()
			local ref = style.size == Style.DISPLAY.size and group.symbol
			return if Boolean.toJSBoolean(ref)
				then not Boolean.toJSBoolean(utils:contains(noSuccessor, group.name))
				else ref
		end)())
	then
		-- Most symbol operators get larger in displaystyle (rule 13)
		large = true
	end
	local base
	if Boolean.toJSBoolean(group.symbol) then
		-- If this is a symbol, create the symbol.
		local fontName = if Boolean.toJSBoolean(large) then "Size2-Regular" else "Size1-Regular"
		local stash = ""
		if group.name == "\\oiint" or group.name == "\\oiiint" then
			-- No font glyphs yet, so use a glyph w/o the oval.
			-- TODO: When font glyphs are available, delete this code.
			stash = Array.slice(group.name, 1) --[[ ROBLOX CHECK: check if 'group.name' is an Array ]]
			group.name = if stash == "oiint" then "\\iint" else "\\iiint"
		end
		base = buildCommon:makeSymbol(group.name, fontName, "math", options, {
			"mop",
			"op-symbol",
			if Boolean.toJSBoolean(large) then "large-op" else "small-op",
		})
		if
			stash.length
			> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
		then
			-- We're in \oiint or \oiiint. Overlay the oval.
			-- TODO: When font glyphs are available, delete this code.
			local italic = base.italic
			local oval = buildCommon:staticSvg(
				tostring(stash) .. "Size" .. (if Boolean.toJSBoolean(large) then "2" else "1"),
				options
			)
			base = buildCommon:makeVList({
				positionType = "individualShift",
				children = {
					{ type = "elem", elem = base, shift = 0 },
					{
						type = "elem",
						elem = oval,
						shift = if Boolean.toJSBoolean(large) then 0.08 else 0,
					},
				},
			}, options)
			group.name = "\\" .. tostring(stash)
			table.insert(base.classes, 1, "mop") --[[ ROBLOX CHECK: check if 'base.classes' is an Array ]] -- $FlowFixMe
			base.italic = italic
		end
	elseif Boolean.toJSBoolean(group.body) then
		-- If this is a list, compose that list.
		local inner = html:buildExpression(group.body, options, true)
		if
			inner.length == 1
			and instanceof(
				inner[
					1 --[[ ROBLOX adaptation: added 1 to array index ]]
				],
				SymbolNode
			)
		then
			base = inner[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
			base.classes[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			] = "mop" -- replace old mclass
		else
			base = buildCommon:makeSpan({ "mop" }, inner, options)
		end
	else
		-- Otherwise, this is a text operator. Build the text from the
		-- operator's name.
		local output = {}
		do
			local i = 1
			while
				i
				< group.name.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				table.insert(
					output,
					buildCommon:mathsym(group.name[tostring(i)], group.mode, options)
				) --[[ ROBLOX CHECK: check if 'output' is an Array ]]
				i += 1
			end
		end
		base = buildCommon:makeSpan({ "mop" }, output, options)
	end -- If content of op is a single symbol, shift it vertically.
	local baseShift = 0
	local slant = 0
	if
		(instanceof(base, SymbolNode) or group.name == "\\oiint" or group.name == "\\oiiint")
		and not Boolean.toJSBoolean(group.suppressBaseShift)
	then
		-- We suppress the shift of the base of \overset and \underset. Otherwise,
		-- shift the symbol so its center lies on the axis (rule 13). It
		-- appears that our fonts have the centers of the symbols already
		-- almost on the axis, so these numbers are very small. Note we
		-- don't actually apply this here, but instead it is used either in
		-- the vlist creation or separately when there are no limits.
		baseShift = (base.height - base.depth) / 2 - options:fontMetrics().axisHeight -- The slant of the symbol is just its italic correction.
		-- $FlowFixMe
		slant = base.italic
	end
	if Boolean.toJSBoolean(hasLimits) then
		return assembleSupSub(base, supGroup, subGroup, options, style, slant, baseShift)
	else
		if Boolean.toJSBoolean(baseShift) then
			base.style.position = "relative"
			base.style.top = makeEm(baseShift)
		end
		return base
	end
end
exports.htmlBuilder = htmlBuilder
local mathmlBuilder: MathMLBuilder<"op">
function mathmlBuilder(group, options)
	local node
	if Boolean.toJSBoolean(group.symbol) then
		-- This is a symbol. Just add the symbol.
		node = mathMLTree.MathNode.new("mo", { mml:makeText(group.name, group.mode) })
		if Boolean.toJSBoolean(utils:contains(noSuccessor, group.name)) then
			node:setAttribute("largeop", "false")
		end
	elseif Boolean.toJSBoolean(group.body) then
		-- This is an operator with children. Add them.
		node = mathMLTree.MathNode.new("mo", mml:buildExpression(group.body, options))
	else
		-- This is a text operator. Add all of the characters from the
		-- operator's name.
		node = mathMLTree.MathNode.new("mi", {
			mathMLTree.TextNode.new(
				Array.slice(group.name, 1) --[[ ROBLOX CHECK: check if 'group.name' is an Array ]]
			),
		}) -- Append an <mo>&ApplyFunction;</mo>.
		-- ref: https://www.w3.org/TR/REC-MathML/chap3_2.html#sec3.2.4
		local operator = mathMLTree.MathNode.new("mo", { mml:makeText("\u{2061}", "text") })
		if Boolean.toJSBoolean(group.parentIsSupSub) then
			node = mathMLTree.MathNode.new("mrow", { node, operator })
		else
			node = mathMLTree:newDocumentFragment({ node, operator })
		end
	end
	return node
end
local singleCharBigOps: { [string]: string } = {
	["\u{220F}"] = "\\prod",
	["\u{2210}"] = "\\coprod",
	["\u{2211}"] = "\\sum",
	["\u{22c0}"] = "\\bigwedge",
	["\u{22c1}"] = "\\bigvee",
	["\u{22c2}"] = "\\bigcap",
	["\u{22c3}"] = "\\bigcup",
	["\u{2a00}"] = "\\bigodot",
	["\u{2a01}"] = "\\bigoplus",
	["\u{2a02}"] = "\\bigotimes",
	["\u{2a04}"] = "\\biguplus",
	["\u{2a06}"] = "\\bigsqcup",
}
defineFunction({
	type = "op",
	names = {
		"\\coprod",
		"\\bigvee",
		"\\bigwedge",
		"\\biguplus",
		"\\bigcap",
		"\\bigcup",
		"\\intop",
		"\\prod",
		"\\sum",
		"\\bigotimes",
		"\\bigoplus",
		"\\bigodot",
		"\\bigsqcup",
		"\\smallint",
		"\u{220F}",
		"\u{2210}",
		"\u{2211}",
		"\u{22c0}",
		"\u{22c1}",
		"\u{22c2}",
		"\u{22c3}",
		"\u{2a00}",
		"\u{2a01}",
		"\u{2a02}",
		"\u{2a04}",
		"\u{2a06}",
	},
	props = { numArgs = 0 },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local fName = funcName
		if fName.length == 1 then
			fName = singleCharBigOps[tostring(fName)]
		end
		return {
			type = "op",
			mode = parser.mode,
			limits = true,
			parentIsSupSub = false,
			symbol = true,
			name = fName,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
}) -- Note: calling defineFunction with a type that's already been defined only
-- works because the same htmlBuilder and mathmlBuilder are being used.
defineFunction({
	type = "op",
	names = { "\\mathop" },
	props = { numArgs = 1, primitive = true },
	handler = function(ref0, args)
		local parser = ref0.parser
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "op",
			mode = parser.mode,
			limits = false,
			parentIsSupSub = false,
			symbol = false,
			body = ordargument(body),
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
}) -- There are 2 flags for operators; whether they produce limits in
-- displaystyle, and whether they are symbols and should grow in
-- displaystyle. These four groups cover the four possible choices.
local singleCharIntegrals: { [string]: string } = {
	["\u{222b}"] = "\\int",
	["\u{222c}"] = "\\iint",
	["\u{222d}"] = "\\iiint",
	["\u{222e}"] = "\\oint",
	["\u{222f}"] = "\\oiint",
	["\u{2230}"] = "\\oiiint",
} -- No limits, not symbols
defineFunction({
	type = "op",
	names = {
		"\\arcsin",
		"\\arccos",
		"\\arctan",
		"\\arctg",
		"\\arcctg",
		"\\arg",
		"\\ch",
		"\\cos",
		"\\cosec",
		"\\cosh",
		"\\cot",
		"\\cotg",
		"\\coth",
		"\\csc",
		"\\ctg",
		"\\cth",
		"\\deg",
		"\\dim",
		"\\exp",
		"\\hom",
		"\\ker",
		"\\lg",
		"\\ln",
		"\\log",
		"\\sec",
		"\\sin",
		"\\sinh",
		"\\sh",
		"\\tan",
		"\\tanh",
		"\\tg",
		"\\th",
	},
	props = { numArgs = 0 },
	handler = function(self, ref0)
		local parser, funcName = ref0.parser, ref0.funcName
		return {
			type = "op",
			mode = parser.mode,
			limits = false,
			parentIsSupSub = false,
			symbol = false,
			name = funcName,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
}) -- Limits, not symbols
defineFunction({
	type = "op",
	names = { "\\det", "\\gcd", "\\inf", "\\lim", "\\max", "\\min", "\\Pr", "\\sup" },
	props = { numArgs = 0 },
	handler = function(self, ref0)
		local parser, funcName = ref0.parser, ref0.funcName
		return {
			type = "op",
			mode = parser.mode,
			limits = true,
			parentIsSupSub = false,
			symbol = false,
			name = funcName,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
}) -- No limits, symbols
defineFunction({
	type = "op",
	names = {
		"\\int",
		"\\iint",
		"\\iiint",
		"\\oint",
		"\\oiint",
		"\\oiiint",
		"\u{222b}",
		"\u{222c}",
		"\u{222d}",
		"\u{222e}",
		"\u{222f}",
		"\u{2230}",
	},
	props = { numArgs = 0 },
	handler = function(self, ref0)
		local parser, funcName = ref0.parser, ref0.funcName
		local fName = funcName
		if fName.length == 1 then
			fName = singleCharIntegrals[tostring(fName)]
		end
		return {
			type = "op",
			mode = parser.mode,
			limits = false,
			parentIsSupSub = false,
			symbol = true,
			name = fName,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
return exports
