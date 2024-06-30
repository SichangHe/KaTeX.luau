-- ROBLOX upstream: https://github.com/SichangHe/KaTeX--KaTeX/blob/ec46deea/src/functions/tag.js
-- @flow
local defineFunctionBuilders = require(script.Parent.Parent.defineFunction).defineFunctionBuilders
local mathMLTree = require(script.Parent.Parent.mathMLTree).default
local mml = require(script.Parent.Parent.buildMathML)
local function pad()
	local padNode = mathMLTree.MathNode.new("mtd", {})
	padNode:setAttribute("width", "50%")
	return padNode
end
defineFunctionBuilders({
	type = "tag",
	mathmlBuilder = function(self, group, options)
		local table_ = mathMLTree.MathNode.new("mtable", {
			mathMLTree.MathNode.new("mtr", {
				pad(),
				mathMLTree.MathNode.new("mtd", { mml:buildExpressionRow(group.body, options) }),
				pad(),
				mathMLTree.MathNode.new("mtd", { mml:buildExpressionRow(group.tag, options) }),
			}),
		})
		table_:setAttribute("width", "100%")
		return table_ -- TODO: Left-aligned tags.
		-- Currently, the group and options passed here do not contain
		-- enough info to set tag alignment. `leqno` is in Settings but it is
		-- not passed to Options. On the HTML side, leqno is
		-- set by a CSS class applied in buildTree.js. That would have worked
		-- in MathML if browsers supported <mlabeledtr>. Since they don't, we
		-- need to rewrite the way this function is called.
	end,
})
