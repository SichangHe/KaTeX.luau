-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/horizBrace.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Boolean = LuauPolyfill.Boolean
local RegExp = require(Packages.RegExp)
local exports = {}
-- @flow
local defineFunction = require(script.Parent.Parent.defineFunction).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local stretchy = require(script.Parent.Parent.stretchy).default
local Style = require(script.Parent.Parent.Style).default
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type HtmlBuilderSupSub = defineFunctionModule.HtmlBuilderSupSub
type MathMLBuilder = defineFunctionModule.MathMLBuilder
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode -- NOTE: Unlike most `htmlBuilder`s, this one handles not only "horizBrace", but
-- also "supsub" since an over/underbrace can affect super/subscripting.
local htmlBuilder: HtmlBuilderSupSub<"horizBrace">
function htmlBuilder(grp, options)
	local style = options.style -- Pull out the `ParseNode<"horizBrace">` if `grp` is a "supsub" node.
	local supSubGroup
	local group: ParseNode<"horizBrace">
	if grp.type == "supsub" then
		-- Ref: LaTeX source2e: }}}}\limits}
		-- i.e. LaTeX treats the brace similar to an op and passes it
		-- with \limits, so we need to assign supsub style.
		supSubGroup = if Boolean.toJSBoolean(grp.sup)
			then html:buildGroup(grp.sup, options:havingStyle(style:sup()), options)
			else html:buildGroup(grp.sub, options:havingStyle(style:sub()), options)
		group = assertNodeType(grp.base, "horizBrace")
	else
		group = assertNodeType(grp, "horizBrace")
	end -- Build the base group
	local body = html:buildGroup(group.base, options:havingBaseStyle(Style.DISPLAY)) -- Create the stretchy element
	local braceBody = stretchy:svgSpan(group, options) -- Generate the vlist, with the appropriate kerns        ┏━━━━━━━━┓
	-- This first vlist contains the content and the brace:   equation
	local vlist
	if Boolean.toJSBoolean(group.isOver) then
		vlist = buildCommon:makeVList({
			positionType = "firstBaseline",
			children = {
				{ type = "elem", elem = body },
				{ type = "kern", size = 0.1 },
				{ type = "elem", elem = braceBody },
			},
		}, options) -- $FlowFixMe: Replace this with passing "svg-align" into makeVList.
		table.insert(
			vlist.children[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].children[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].children[
				2 --[[ ROBLOX adaptation: added 1 to array index ]]
			].classes,
			"svg-align"
		) --[[ ROBLOX CHECK: check if 'vlist.children[0].children[0].children[1].classes' is an Array ]]
	else
		vlist = buildCommon:makeVList({
			positionType = "bottom",
			positionData = body.depth + 0.1 + braceBody.height,
			children = {
				{ type = "elem", elem = braceBody },
				{ type = "kern", size = 0.1 },
				{ type = "elem", elem = body },
			},
		}, options) -- $FlowFixMe: Replace this with passing "svg-align" into makeVList.
		table.insert(
			vlist.children[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].children[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].children[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			].classes,
			"svg-align"
		) --[[ ROBLOX CHECK: check if 'vlist.children[0].children[0].children[0].classes' is an Array ]]
	end
	if Boolean.toJSBoolean(supSubGroup) then
		-- To write the supsub, wrap the first vlist in another vlist:
		-- They can't all go in the same vlist, because the note might be
		-- wider than the equation. We want the equation to control the
		-- brace width.
		--      note          long note           long note
		--   ┏━━━━━━━━┓   or    ┏━━━┓     not    ┏━━━━━━━━━┓
		--    equation           eqn                 eqn
		local vSpan = buildCommon:makeSpan({
			"mord",
			if Boolean.toJSBoolean(group.isOver) then "mover" else "munder",
		}, { vlist }, options)
		if Boolean.toJSBoolean(group.isOver) then
			vlist = buildCommon:makeVList({
				positionType = "firstBaseline",
				children = {
					{ type = "elem", elem = vSpan },
					{ type = "kern", size = 0.2 },
					{ type = "elem", elem = supSubGroup },
				},
			}, options)
		else
			vlist = buildCommon:makeVList({
				positionType = "bottom",
				positionData = vSpan.depth + 0.2 + supSubGroup.height + supSubGroup.depth,
				children = {
					{ type = "elem", elem = supSubGroup },
					{ type = "kern", size = 0.2 },
					{ type = "elem", elem = vSpan },
				},
			}, options)
		end
	end
	return buildCommon:makeSpan({
		"mord",
		if Boolean.toJSBoolean(group.isOver) then "mover" else "munder",
	}, { vlist }, options)
end
exports.htmlBuilder = htmlBuilder
local mathmlBuilder: MathMLBuilder<"horizBrace">
function mathmlBuilder(group, options)
	local accentNode = stretchy:mathMLnode(group.label)
	return mathMLTree.MathNode.new(
		if Boolean.toJSBoolean(group.isOver) then "mover" else "munder",
		{ mml:buildGroup(group.base, options), accentNode }
	)
end -- Horizontal stretchy braces
defineFunction({
	type = "horizBrace",
	names = { "\\overbrace", "\\underbrace" },
	props = { numArgs = 1 },
	handler = function(self, ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		return {
			type = "horizBrace",
			mode = parser.mode,
			label = funcName,
			isOver = RegExp("^\\\\over"):test(funcName),
			base = args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			],
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
return exports
