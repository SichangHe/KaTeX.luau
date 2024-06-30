-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/accent.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local exports = {}
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local normalizeArgument = defineFunctionModule.normalizeArgument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local utils = require(script.Parent.Parent.utils).default
local stretchy = require(script.Parent.Parent.stretchy).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local domTreeModule = require(script.Parent.Parent.domTree)
local assertSpan = domTreeModule.assertSpan
local assertSymbolDomNode = domTreeModule.assertSymbolDomNode
local makeEm = require(script.Parent.Parent.units).makeEm
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode
type AnyParseNode = parseNodeModule.AnyParseNode
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type HtmlBuilderSupSub = defineFunctionModule.HtmlBuilderSupSub
type MathMLBuilder = defineFunctionModule.MathMLBuilder -- NOTE: Unlike most `htmlBuilder`s, this one handles not only "accent", but
-- also "supsub" since an accent can affect super/subscripting.
local htmlBuilder: HtmlBuilderSupSub<"accent">
function htmlBuilder(grp, options)
	-- Accents are handled in the TeXbook pg. 443, rule 12.
	local base: AnyParseNode
	local group: ParseNode<"accent">
	local supSubGroup
	if Boolean.toJSBoolean(if Boolean.toJSBoolean(grp) then grp.type == "supsub" else grp) then
		-- If our base is a character box, and we have superscripts and
		-- subscripts, the supsub will defer to us. In particular, we want
		-- to attach the superscripts and subscripts to the inner body (so
		-- that the position of the superscripts and subscripts won't be
		-- affected by the height of the accent). We accomplish this by
		-- sticking the base of the accent into the base of the supsub, and
		-- rendering that, while keeping track of where the accent is.
		-- The real accent group is the base of the supsub group
		group = assertNodeType(grp.base, "accent") -- The character box is the base of the accent group
		base = group.base -- Stick the character box into the base of the supsub group
		grp.base = base -- Rerender the supsub group with its new base, and store that
		-- result.
		supSubGroup = assertSpan(html:buildGroup(grp, options)) -- reset original base
		grp.base = group
	else
		group = assertNodeType(grp, "accent")
		base = group.base
	end -- Build the base group
	local body = html:buildGroup(base, options:havingCrampedStyle()) -- Does the accent need to shift for the skew of a character?
	local mustShift = if Boolean.toJSBoolean(group.isShifty)
		then utils:isCharacterBox(base)
		else group.isShifty -- Calculate the skew of the accent. This is based on the line "If the
	-- nucleus is not a single character, let s = 0; otherwise set s to the
	-- kern amount for the nucleus followed by the \skewchar of its font."
	-- Note that our skew metrics are just the kern between each character
	-- and the skewchar.
	local skew = 0
	if Boolean.toJSBoolean(mustShift) then
		-- If the base is a character box, then we want the skew of the
		-- innermost character. To do that, we find the innermost character:
		local baseChar = utils:getBaseElem(base) -- Then, we render its group to get the symbol inside it
		local baseGroup = html:buildGroup(baseChar, options:havingCrampedStyle()) -- Finally, we pull the skew off of the symbol.
		skew = assertSymbolDomNode(baseGroup).skew -- Note that we now throw away baseGroup, because the layers we
		-- removed with getBaseElem might contain things like \color which
		-- we can't get rid of.
		-- TODO(emily): Find a better way to get the skew
	end
	local accentBelow = group.label == "\\c" -- calculate the amount of space between the body and the accent
	local clearance = if Boolean.toJSBoolean(accentBelow)
		then body.height + body.depth
		else math.min(body.height, options:fontMetrics().xHeight) -- Build the accent
	local accentBody
	if not Boolean.toJSBoolean(group.isStretchy) then
		local accent
		local width: number
		if group.label == "\\vec" then
			-- Before version 0.9, \vec used the combining font glyph U+20D7.
			-- But browsers, especially Safari, are not consistent in how they
			-- render combining characters when not preceded by a character.
			-- So now we use an SVG.
			-- If Safari reforms, we should consider reverting to the glyph.
			accent = buildCommon:staticSvg("vec", options)
			width = buildCommon.svgData.vec[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			]
		else
			accent =
				buildCommon:makeOrd({ mode = group.mode, text = group.label }, options, "textord")
			accent = assertSymbolDomNode(accent) -- Remove the italic correction of the accent, because it only serves to
			-- shift the accent over to a place we don't want.
			accent.italic = 0
			width = accent.width
			if Boolean.toJSBoolean(accentBelow) then
				clearance += accent.depth
			end
		end
		accentBody = buildCommon:makeSpan({ "accent-body" }, { accent }) -- "Full" accents expand the width of the resulting symbol to be
		-- at least the width of the accent, and overlap directly onto the
		-- character without any vertical offset.
		local accentFull = group.label == "\\textcircled"
		if Boolean.toJSBoolean(accentFull) then
			table.insert(accentBody.classes, "accent-full") --[[ ROBLOX CHECK: check if 'accentBody.classes' is an Array ]]
			clearance = body.height
		end -- Shift the accent over by the skew.
		local left = skew -- CSS defines `.katex .accent .accent-body:not(.accent-full) { width: 0 }`
		-- so that the accent doesn't contribute to the bounding box.
		-- We need to shift the character by its width (effectively half
		-- its width) to compensate.
		if not Boolean.toJSBoolean(accentFull) then
			left -= width / 2
		end
		accentBody.style.left = makeEm(left) -- \textcircled uses the \bigcirc glyph, so it needs some
		-- vertical adjustment to match LaTeX.
		if group.label == "\\textcircled" then
			accentBody.style.top = ".2em"
		end
		accentBody = buildCommon:makeVList({
			positionType = "firstBaseline",
			children = {
				{ type = "elem", elem = body },
				{ type = "kern", size = -clearance },
				{ type = "elem", elem = accentBody },
			},
		}, options)
	else
		accentBody = stretchy:svgSpan(group, options)
		accentBody = buildCommon:makeVList({
			positionType = "firstBaseline",
			children = {
				{ type = "elem", elem = body },
				{
					type = "elem",
					elem = accentBody,
					wrapperClasses = { "svg-align" },
					wrapperStyle = if skew
							> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
						then {
							width = ("calc(100%% - %s)"):format(tostring(makeEm(2 * skew))),
							marginLeft = makeEm(2 * skew),
						}
						else nil,
				},
			},
		}, options)
	end
	local accentWrap = buildCommon:makeSpan({ "mord", "accent" }, { accentBody }, options)
	if Boolean.toJSBoolean(supSubGroup) then
		-- Here, we replace the "base" child of the supsub with our newly
		-- generated accent.
		supSubGroup.children[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		] =
			accentWrap -- Since we don't rerun the height calculation after replacing the
		-- accent, we manually recalculate height.
		supSubGroup.height = math.max(accentWrap.height, supSubGroup.height) -- Accents should always be ords, even when their innards are not.
		supSubGroup.classes[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		] = "mord"
		return supSubGroup
	else
		return accentWrap
	end
end
exports.htmlBuilder = htmlBuilder
local mathmlBuilder: MathMLBuilder<"accent">
function mathmlBuilder(group, options)
	local accentNode = if Boolean.toJSBoolean(group.isStretchy)
		then stretchy:mathMLnode(group.label)
		else mathMLTree.MathNode.new("mo", { mml:makeText(group.label, group.mode) })
	local node =
		mathMLTree.MathNode.new("mover", { mml:buildGroup(group.base, options), accentNode })
	node:setAttribute("accent", "true")
	return node
end
local NON_STRETCHY_ACCENT_REGEX = RegExp.new(Array.join(
	Array.map({
		"\\acute",
		"\\grave",
		"\\ddot",
		"\\tilde",
		"\\bar",
		"\\breve",
		"\\check",
		"\\hat",
		"\\vec",
		"\\dot",
		"\\mathring",
	}, function(accent)
		return ("\\%s"):format(tostring(accent))
	end),
	"|"
)) -- Accents
defineFunction({
	type = "accent",
	names = {
		"\\acute",
		"\\grave",
		"\\ddot",
		"\\tilde",
		"\\bar",
		"\\breve",
		"\\check",
		"\\hat",
		"\\vec",
		"\\dot",
		"\\mathring",
		"\\widecheck",
		"\\widehat",
		"\\widetilde",
		"\\overrightarrow",
		"\\overleftarrow",
		"\\Overrightarrow",
		"\\overleftrightarrow",
		"\\overgroup",
		"\\overlinesegment",
		"\\overleftharpoon",
		"\\overrightharpoon",
	},
	props = { numArgs = 1 },
	handler = function(context, args)
		local base = normalizeArgument(args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		])
		local isStretchy = not Boolean.toJSBoolean(NON_STRETCHY_ACCENT_REGEX:test(context.funcName))
		local isShifty = not Boolean.toJSBoolean(isStretchy)
			or context.funcName == "\\widehat"
			or context.funcName == "\\widetilde"
			or context.funcName == "\\widecheck"
		return {
			type = "accent",
			mode = context.parser.mode,
			label = context.funcName,
			isStretchy = isStretchy,
			isShifty = isShifty,
			base = base,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
}) -- Text-mode accents
defineFunction({
	type = "accent",
	names = {
		"\\'",
		"\\`",
		"\\^",
		"\\~",
		"\\=",
		"\\u",
		"\\.",
		'\\"',
		"\\c",
		"\\r",
		"\\H",
		"\\v",
		"\\textcircled",
	},
	props = {
		numArgs = 1,
		allowedInText = true,
		allowedInMath = true,
		-- unless in strict mode
		argTypes = { "primitive" },
	},
	handler = function(context, args)
		local base = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		local mode = context.parser.mode
		if mode == "math" then
			context.parser.settings:reportNonstrict(
				"mathVsTextAccents",
				("LaTeX's accent %s works only in text mode"):format(tostring(context.funcName))
			)
			mode = "text"
		end
		return {
			type = "accent",
			mode = mode,
			label = context.funcName,
			isStretchy = false,
			isShifty = true,
			base = base,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
return exports
