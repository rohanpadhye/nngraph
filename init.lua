require 'nn'
require 'graph'
require 'dpnn'

nngraph = {}

require('nngraph.nest')
require('nngraph.node')
require('nngraph.gmodule')
require('nngraph.graphinspecting')
require('nngraph.JustElement')
require('nngraph.JustTable')
require('nngraph.ModuleFromCriterion')

-- handy functions
local utils = require('nngraph.utils')
local istensor = torch.isTensor
local istable = utils.istable
local istorchclass = utils.istorchclass

-- simpler todot functions
nngraph.simple_print =  require('nngraph.simple_print')

-- Modify the __call function to hack into nn.Module
local Module = torch.getmetatable('nn.Module')
function Module:__call__(...)
   local nArgs = select("#", ...)
   assert(nArgs <= 1, 'Use {input1, input2} to pass multiple inputs.')

   local input = ...
   if nArgs == 1 and input == nil then
      error(utils.expectingNodeErrorMessage(input, 'inputs', 1))
   end
   -- Disallow passing empty table, in case someone passes a table with some
   -- typo'd variable name in.
   if type(input) == 'table' and next(input) == nil then
      error('cannot pass an empty table of inputs. To indicate no incoming ' ..
            'connections, leave the second set of parens blank.')
   end
   if not istable(input) then
      input = {input}
   end
   local mnode = nngraph.Node({module=self:getGraphClone(), prototype=self})

   local dnode
   for i = 1, utils.tableMaxN(input) do
      dnode = input[i]
      if torch.typename(dnode) ~= 'nngraph.Node' then
         error(utils.expectingNodeErrorMessage(dnode, 'inputs', i))
      end
      mnode:add(dnode,true)
   end

   return mnode
end

local graphClones = {}
local gcMeta = {}
setmetatable(graphClones, gcMeta)
gcMeta.__mode = "k"

function Module:getGraphClone()
	if not graphClones[self] then
		graphClones[self] = {}
	end
	clones = graphClones[self]
	self.nextClone = self.nextClone or 1
	local clone = nil
	if self.nextClone <= #clones then
		clone = clones[self.nextClone]
	else
		assert(self.nextClone == #clones + 1)
		clone = self:sharedClone(true, true, true)
		table.insert(clones, clone)
	end
	self.nextClone = self.nextClone + 1
	return clone
end

function Module:recycleClones()
	self.nextClone = 1
end

local Criterion = torch.getmetatable('nn.Criterion')
function Criterion:__call__(...)
   return nn.ModuleFromCriterion(self)(...)
end

return nngraph
