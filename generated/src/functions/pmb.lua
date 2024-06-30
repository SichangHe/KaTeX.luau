-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/pmb.js
-- @flow
local defineFunctionModule = require(script.Parent.Parent.defineFunction)
local defineFunction = defineFunctionModule.default
local ordargument = defineFunctionModule.ordargument
local buildCommon = require(script.Parent.Parent.buildCommon).default
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local html = require(script.Parent.Parent.buildHTML)
local mml = require(script.Parent.Parent.buildMathML)
local binrelClass = require(script.Parent.mclass).binrelClass
local parseNodeModule = require(script.Parent.Parent.parseNode)
type ParseNode = parseNodeModule.ParseNode -- \pmb is a simulation of bold font.
-- The version of \pmb in ambsy.sty works by typesetting three copies
-- with small offsets. We use CSS text-shadow.
-- It's a hack. Not as good as a real bold font. Better than nothing.
defineFunction({
	type = "pmb",
	names = { "\\pmb" },
	props = { numArgs = 1, allowedInText = true },
	handler = function(self, ref0, args)
		local parser = ref0.parser
		return {
			type = "pmb",
			mode = parser.mode,
			mclass = binrelClass(args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
			body = ordargument(args[
				1 --[[ ROBLOX adaptation: added 1 to array index ]]
			]),
		}
	end,
	htmlBuilder = function(self, group: ParseNode<"pmb">, options)
		local elements = html:buildExpression(group.body, options, true)
		local node = buildCommon:makeSpan({ group.mclass }, elements, options)
		node.style.textShadow = "0.02em 0.01em 0.04px"
		return node
	end,
	mathmlBuilder = function(self, group: ParseNode<"pmb">, style)
		local inner = mml:buildExpression(group.body, style) -- Wrap with an <mstyle> element.
		local node = mathMLTree.MathNode.new("mstyle", inner)
		node:setAttribute("style", "text-shadow: 0.02em 0.01em 0.04px")
		return node
	end,
})
