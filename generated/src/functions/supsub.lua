-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/supsub.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local Error = LuauPolyfill.Error
local instanceof = LuauPolyfill.instanceof
-- @flow
local defineFunctionBuilders = require(script.Parent.Parent.defineFunction).defineFunctionBuilders
local buildCommon = require(script.Parent.Parent.buildCommon).default
local SymbolNode = require(script.Parent.Parent.domTree).SymbolNode
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local utils = require(script.Parent.Parent.utils).default
local makeEm = require(script.Parent.Parent.units).makeEm
local Style = require(script.Parent.Parent.Style).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local accent = require(script.Parent.accent)
local horizBrace = require(script.Parent.horizBrace)
local op = require(script.Parent.op)
local operatorname = require(script.Parent.operatorname)
local optionsModule = require(script.Parent.Parent.Options)
type Options = optionsModule.default
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type HtmlBuilder = defineFunctionModule.HtmlBuilder
local mathMLTreeModule = require(script.Parent.Parent.mathMLTree)
type MathNodeType = mathMLTreeModule.MathNodeType
--[[*
 * Sometimes, groups perform special rules when they have superscripts or
 * subscripts attached to them. This function lets the `supsub` group know that
 * Sometimes, groups perform special rules when they have superscripts or
 * its inner element should handle the superscripts and subscripts instead of
 * handling them itself.
 ]]
local function htmlBuilderDelegate(
	group: ParseNode<"supsub">,
	options: Options
): HtmlBuilder<any --[[ ROBLOX TODO: Unhandled node for type: ExistsTypeAnnotation ]] --[[ * ]]>?
	local base = group.base
	if not Boolean.toJSBoolean(base) then
		return nil
	elseif base.type == "op" then
		-- Operators handle supsubs differently when they have limits
		-- (e.g. `\displaystyle\sum_2^3`)
		local delegate = if Boolean.toJSBoolean(base.limits)
			then options.style.size == Style.DISPLAY.size or base.alwaysHandleSupSub
			else base.limits
		return if Boolean.toJSBoolean(delegate) then op.htmlBuilder else nil
	elseif base.type == "operatorname" then
		local delegate = if Boolean.toJSBoolean(base.alwaysHandleSupSub)
			then options.style.size == Style.DISPLAY.size or base.limits
			else base.alwaysHandleSupSub
		return if Boolean.toJSBoolean(delegate) then operatorname.htmlBuilder else nil
	elseif base.type == "accent" then
		return if Boolean.toJSBoolean(utils:isCharacterBox(base.base))
			then accent.htmlBuilder
			else nil
	elseif base.type == "horizBrace" then
		local isSup = not Boolean.toJSBoolean(group.sub)
		return if isSup == base.isOver then horizBrace.htmlBuilder else nil
	else
		return nil
	end
end
-- Super scripts and subscripts, whose precise placement can depend on other
-- functions that precede them.
defineFunctionBuilders({
	type = "supsub",
	htmlBuilder = function(self, group, options)
		-- Superscript and subscripts are handled in the TeXbook on page
		-- 445-446, rules 18(a-f).
		-- Here is where we defer to the inner group if it should handle
		-- superscripts and subscripts itself.
		local builderDelegate = htmlBuilderDelegate(group, options)
		if Boolean.toJSBoolean(builderDelegate) then
			return builderDelegate(group, options)
		end
		local valueBase, valueSup, valueSub = group.base, group.sup, group.sub
		local base = html:buildGroup(valueBase, options)
		local supm
		local subm
		local metrics = options:fontMetrics()
		-- Rule 18a
		local supShift = 0
		local subShift = 0
		local isCharacterBox = if Boolean.toJSBoolean(valueBase)
			then utils:isCharacterBox(valueBase)
			else valueBase
		if Boolean.toJSBoolean(valueSup) then
			local newOptions = options:havingStyle(options.style:sup())
			supm = html:buildGroup(valueSup, newOptions, options)
			if not Boolean.toJSBoolean(isCharacterBox) then
				supShift = base.height
					- newOptions:fontMetrics().supDrop
						* newOptions.sizeMultiplier
						/ options.sizeMultiplier
			end
		end
		if Boolean.toJSBoolean(valueSub) then
			local newOptions = options:havingStyle(options.style:sub())
			subm = html:buildGroup(valueSub, newOptions, options)
			if not Boolean.toJSBoolean(isCharacterBox) then
				subShift = base.depth
					+ newOptions:fontMetrics().subDrop
						* newOptions.sizeMultiplier
						/ options.sizeMultiplier
			end
		end
		-- Rule 18c
		local minSupShift
		if options.style == Style.DISPLAY then
			minSupShift = metrics.sup1
		elseif Boolean.toJSBoolean(options.style.cramped) then
			minSupShift = metrics.sup3
		else
			minSupShift = metrics.sup2
		end
		-- scriptspace is a font-size-independent size, so scale it
		-- appropriately for use as the marginRight.
		local multiplier = options.sizeMultiplier
		local marginRight = makeEm(0.5 / metrics.ptPerEm / multiplier)
		local marginLeft = nil
		if Boolean.toJSBoolean(subm) then
			-- Subscripts shouldn't be shifted by the base's italic correction.
			-- Account for that by shifting the subscript back the appropriate
			-- amount. Note we only do this when the base is a single symbol.
			local ref = if Boolean.toJSBoolean(group.base)
				then group.base.type == "op"
				else group.base
			local ref = if Boolean.toJSBoolean(ref) then group.base.name else ref
			local isOiint = if Boolean.toJSBoolean(ref)
				then group.base.name == "\\oiint" or group.base.name == "\\oiiint"
				else ref
			if Boolean.toJSBoolean(instanceof(base, SymbolNode) or isOiint) then
				-- $FlowFixMe
				marginLeft = makeEm(-base.italic)
			end
		end
		local supsub
		if Boolean.toJSBoolean(if Boolean.toJSBoolean(supm) then subm else supm) then
			supShift = math.max(supShift, minSupShift, supm.depth + 0.25 * metrics.xHeight)
			subShift = math.max(subShift, metrics.sub2)
			local ruleWidth = metrics.defaultRuleThickness
			-- Rule 18e
			local maxWidth = 4 * ruleWidth
			if
				supShift - supm.depth - (subm.height - subShift)
				< maxWidth --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			then
				subShift = maxWidth - (supShift - supm.depth) + subm.height
				local psi = 0.8 * metrics.xHeight - (supShift - supm.depth)
				if
					psi
					> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
				then
					supShift += psi
					subShift -= psi
				end
			end
			local vlistElem = {
				{
					type = "elem",
					elem = subm,
					shift = subShift,
					marginRight = marginRight,
					marginLeft = marginLeft,
				},
				{ type = "elem", elem = supm, shift = -supShift, marginRight = marginRight },
			}
			supsub = buildCommon:makeVList(
				{ positionType = "individualShift", children = vlistElem },
				options
			)
		elseif Boolean.toJSBoolean(subm) then
			-- Rule 18b
			subShift = math.max(subShift, metrics.sub1, subm.height - 0.8 * metrics.xHeight)
			local vlistElem = {
				{ type = "elem", elem = subm, marginLeft = marginLeft, marginRight = marginRight },
			}
			supsub = buildCommon:makeVList(
				{ positionType = "shift", positionData = subShift, children = vlistElem },
				options
			)
		elseif Boolean.toJSBoolean(supm) then
			-- Rule 18c, d
			supShift = math.max(supShift, minSupShift, supm.depth + 0.25 * metrics.xHeight)
			supsub = buildCommon:makeVList({
				positionType = "shift",
				positionData = -supShift,
				children = { { type = "elem", elem = supm, marginRight = marginRight } },
			}, options)
		else
			error(Error.new("supsub must have either sup or sub."))
		end
		-- Wrap the supsub vlist in a span.msupsub to reset text-align.
		local ref = html:getTypeOfDomTree(base, "right")
		local mclass = Boolean.toJSBoolean(ref) and ref or "mord"
		return buildCommon:makeSpan(
			{ mclass },
			{ base, buildCommon:makeSpan({ "msupsub" }, { supsub }) },
			options
		)
	end,
	mathmlBuilder = function(self, group, options)
		-- Is the inner group a relevant horizonal brace?
		local isBrace = false
		local isOver
		local isSup
		if
			Boolean.toJSBoolean(
				if Boolean.toJSBoolean(group.base)
					then group.base.type == "horizBrace"
					else group.base
			)
		then
			isSup = not not Boolean.toJSBoolean(group.sup)
			if isSup == group.base.isOver then
				isBrace = true
				isOver = group.base.isOver
			end
		end
		if
			Boolean.toJSBoolean(
				if Boolean.toJSBoolean(group.base)
					then group.base.type == "op" or group.base.type == "operatorname"
					else group.base
			)
		then
			group.base.parentIsSupSub = true
		end
		local children = { mml:buildGroup(group.base, options) }
		if Boolean.toJSBoolean(group.sub) then
			table.insert(children, mml:buildGroup(group.sub, options)) --[[ ROBLOX CHECK: check if 'children' is an Array ]]
		end
		if Boolean.toJSBoolean(group.sup) then
			table.insert(children, mml:buildGroup(group.sup, options)) --[[ ROBLOX CHECK: check if 'children' is an Array ]]
		end
		local nodeType: MathNodeType
		if Boolean.toJSBoolean(isBrace) then
			nodeType = if Boolean.toJSBoolean(isOver) then "mover" else "munder"
		elseif not Boolean.toJSBoolean(group.sub) then
			local base = group.base
			if
				Boolean.toJSBoolean((function()
					local ref = if Boolean.toJSBoolean(base) then base.type == "op" else base
					local ref = if Boolean.toJSBoolean(ref) then base.limits else ref
					return if Boolean.toJSBoolean(ref)
						then options.style == Style.DISPLAY or base.alwaysHandleSupSub
						else ref
				end)())
			then
				nodeType = "mover"
			elseif
				Boolean.toJSBoolean((function()
					local ref = if Boolean.toJSBoolean(base)
						then base.type == "operatorname"
						else base
					local ref = if Boolean.toJSBoolean(ref) then base.alwaysHandleSupSub else ref
					return if Boolean.toJSBoolean(ref)
						then Boolean.toJSBoolean(base.limits) and base.limits
							or options.style == Style.DISPLAY
						else ref
				end)())
			then
				nodeType = "mover"
			else
				nodeType = "msup"
			end
		elseif not Boolean.toJSBoolean(group.sup) then
			local base = group.base
			if
				Boolean.toJSBoolean((function()
					local ref = if Boolean.toJSBoolean(base) then base.type == "op" else base
					local ref = if Boolean.toJSBoolean(ref) then base.limits else ref
					return if Boolean.toJSBoolean(ref)
						then options.style == Style.DISPLAY or base.alwaysHandleSupSub
						else ref
				end)())
			then
				nodeType = "munder"
			elseif
				Boolean.toJSBoolean((function()
					local ref = if Boolean.toJSBoolean(base)
						then base.type == "operatorname"
						else base
					local ref = if Boolean.toJSBoolean(ref) then base.alwaysHandleSupSub else ref
					return if Boolean.toJSBoolean(ref)
						then Boolean.toJSBoolean(base.limits) and base.limits
							or options.style == Style.DISPLAY
						else ref
				end)())
			then
				nodeType = "munder"
			else
				nodeType = "msub"
			end
		else
			local base = group.base
			if
				Boolean.toJSBoolean((function()
					local ref = if Boolean.toJSBoolean(base) then base.type == "op" else base
					local ref = if Boolean.toJSBoolean(ref) then base.limits else ref
					return if Boolean.toJSBoolean(ref) then options.style == Style.DISPLAY else ref
				end)())
			then
				nodeType = "munderover"
			elseif
				Boolean.toJSBoolean((function()
					local ref = if Boolean.toJSBoolean(base)
						then base.type == "operatorname"
						else base
					local ref = if Boolean.toJSBoolean(ref) then base.alwaysHandleSupSub else ref
					return if Boolean.toJSBoolean(ref)
						then options.style == Style.DISPLAY or base.limits
						else ref
				end)())
			then
				nodeType = "munderover"
			else
				nodeType = "msubsup"
			end
		end
		return mathMLTree.MathNode.new(nodeType, children)
	end,
})
