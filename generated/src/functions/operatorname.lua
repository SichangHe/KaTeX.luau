-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/operatorname.js
local Packages --[[ ROBLOX comment: must define Packages module ]]
local LuauPolyfill = require(Packages.LuauPolyfill)
local Array = LuauPolyfill.Array
local Boolean = LuauPolyfill.Boolean
local instanceof = LuauPolyfill.instanceof
local RegExp = require(Packages.RegExp)
local exports = {}
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local defineMacro = require(script.Parent.Parent.defineMacro).default
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local SymbolNode = require(script.Parent.Parent.domTree).SymbolNode
local assembleSupSub = require(script.Parent.utils.assembleSupSub).assembleSupSub
local assertNodeType = require(script.Parent.Parent.parseNode).assertNodeType
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
type HtmlBuilderSupSub = defineFunctionModule.HtmlBuilderSupSub
type MathMLBuilder = defineFunctionModule.MathMLBuilder
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode -- NOTE: Unlike most `htmlBuilder`s, this one handles not only
-- "operatorname", but also  "supsub" since \operatorname* can
-- affect super/subscripting.
local htmlBuilder: HtmlBuilderSupSub<"operatorname">
function htmlBuilder(grp, options)
	-- Operators are handled in the TeXbook pg. 443-444, rule 13(a).
	local supGroup
	local subGroup
	local hasLimits = false
	local group: ParseNode<"operatorname">
	if grp.type == "supsub" then
		-- If we have limits, supsub will pass us its group to handle. Pull
		-- out the superscript and subscript and set the group to the op in
		-- its base.
		supGroup = grp.sup
		subGroup = grp.sub
		group = assertNodeType(grp.base, "operatorname")
		hasLimits = true
	else
		group = assertNodeType(grp, "operatorname")
	end
	local base
	if
		group.body.length
		> 0 --[[ ROBLOX CHECK: operator '>' works only if either both arguments are strings or both are a number ]]
	then
		local body = Array.map(group.body, function(child)
			-- $FlowFixMe: Check if the node has a string `text` property.
			local childText = child.text
			if typeof(childText) == "string" then
				return { type = "textord", mode = child.mode, text = childText }
			else
				return child
			end
		end) --[[ ROBLOX CHECK: check if 'group.body' is an Array ]] -- Consolidate function names into symbol characters.
		local expression = html:buildExpression(body, options:withFont("mathrm"), true)
		do
			local i = 0
			while
				i
				< expression.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
			do
				local child = expression[tostring(i)]
				if instanceof(child, SymbolNode) then
					-- Per amsopn package,
					-- change minus to hyphen and \ast to asterisk
					child.text =
						child.text:replace(RegExp("\\u2212"), "-"):replace(RegExp("\\u2217"), "*")
				end
				i += 1
			end
		end
		base = buildCommon:makeSpan({ "mop" }, expression, options)
	else
		base = buildCommon:makeSpan({ "mop" }, {}, options)
	end
	if Boolean.toJSBoolean(hasLimits) then
		return assembleSupSub(base, supGroup, subGroup, options, options.style, 0, 0)
	else
		return base
	end
end
exports.htmlBuilder = htmlBuilder
local mathmlBuilder: MathMLBuilder<"operatorname">
function mathmlBuilder(group, options)
	-- The steps taken here are similar to the html version.
	local expression = mml:buildExpression(group.body, options:withFont("mathrm")) -- Is expression a string or has it something like a fraction?
	local isAllString = true -- default
	do
		local i = 0
		while
			i
			< expression.length --[[ ROBLOX CHECK: operator '<' works only if either both arguments are strings or both are a number ]]
		do
			local node = expression[tostring(i)]
			if instanceof(node, mathMLTree.SpaceNode) then
			-- Do nothing
			elseif instanceof(node, mathMLTree.MathNode) then
				repeat --[[ ROBLOX comment: switch statement conversion ]]
					local condition_ = node.type
					if
						condition_ == "mi"
						or condition_ == "mn"
						or condition_ == "ms"
						or condition_ == "mspace"
						or condition_ == "mtext"
					then
						break
					elseif condition_ == "mo" then
						do
							local child = node.children[
								1 --[[ ROBLOX adaptation: added 1 to array index ]]
							]
							if
								node.children.length == 1 and instanceof(child, mathMLTree.TextNode)
							then
								child.text = child.text
									:replace(RegExp("\\u2212"), "-")
									:replace(RegExp("\\u2217"), "*")
							else
								isAllString = false
							end
							break
						end
					else
						isAllString = false
					end
				until true
			else
				isAllString = false
			end
			i += 1
		end
	end
	if Boolean.toJSBoolean(isAllString) then
		-- Write a single TextNode instead of multiple nested tags.
		local word = Array.join(
			Array.map(expression, function(node)
				return node:toText()
			end), --[[ ROBLOX CHECK: check if 'expression' is an Array ]]
			""
		)
		expression = { mathMLTree.TextNode.new(word) }
	end
	local identifier = mathMLTree.MathNode.new("mi", expression)
	identifier:setAttribute("mathvariant", "normal") -- \u2061 is the same as &ApplyFunction;
	-- ref: https://www.w3schools.com/charsets/ref_html_entities_a.asp
	local operator = mathMLTree.MathNode.new("mo", { mml:makeText("\u{2061}", "text") })
	if Boolean.toJSBoolean(group.parentIsSupSub) then
		return mathMLTree.MathNode.new("mrow", { identifier, operator })
	else
		return mathMLTree:newDocumentFragment({ identifier, operator })
	end
end -- \operatorname
-- amsopn.dtx: \mathop{#1\kern\z@\operator@font#3}\newmcodes@
defineFunction({
	type = "operatorname",
	names = { "\\operatorname@", "\\operatornamewithlimits" },
	props = { numArgs = 1 },
	handler = function(ref0, args)
		local parser, funcName = ref0.parser, ref0.funcName
		local body = args[
			1 --[[ ROBLOX adaptation: added 1 to array index ]]
		]
		return {
			type = "operatorname",
			mode = parser.mode,
			body = ordargument(body),
			alwaysHandleSupSub = funcName == "\\operatornamewithlimits",
			limits = false,
			parentIsSupSub = false,
		}
	end,
	htmlBuilder = htmlBuilder,
	mathmlBuilder = mathmlBuilder,
})
defineMacro("\\operatorname", "\\@ifstar\\operatornamewithlimits\\operatorname@")
return exports
