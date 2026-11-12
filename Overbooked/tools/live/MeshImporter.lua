-- Run a Hotel edit-time tool: rah_props.py JSON (served on :8790) -> EditableMesh -> uploaded MeshPart.
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local M = {}
M.BASE = "http://127.0.0.1:8790/"

M.LOOKS = {
	main = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(1, 1, 1) },
	chrome = { Material = Enum.Material.Metal, Color = Color3.new(1, 1, 1), Reflectance = 0.25 },
	glass = { Material = Enum.Material.Glass, Color = Color3.fromRGB(210, 236, 244), Transparency = 0.6 },
	glow = { Material = Enum.Material.SmoothPlastic, Color = Color3.new(1, 1, 1) },
}

function M.fetch(name)
	return HttpService:JSONDecode(HttpService:GetAsync(M.BASE .. name .. ".json"))
end

function M.build(d)
	local em = AssetService:CreateEditableMesh()
	local pos, nrm, col = d.pos, d.nrm, d.col
	local vid, nid, cid = {}, {}, {}
	for i = 0, #pos / 3 - 1 do vid[i] = em:AddVertex(Vector3.new(pos[i*3+1], pos[i*3+2], pos[i*3+3])) end
	for i = 0, #nrm / 3 - 1 do nid[i] = em:AddNormal(Vector3.new(nrm[i*3+1], nrm[i*3+2], nrm[i*3+3])) end
	for i = 0, #col / 3 - 1 do cid[i] = em:AddColor(Color3.fromRGB(col[i*3+1], col[i*3+2], col[i*3+3]), 1) end
	local uv0 = em:AddUV(Vector2.zero)
	local tri, tn, tc = d.tri, d.tn, d.tc
	for f = 0, #tri / 3 - 1 do
		local a, b, c = f*3+1, f*3+2, f*3+3
		local fid = em:AddTriangle(vid[tri[a]], vid[tri[b]], vid[tri[c]])
		em:SetFaceNormals(fid, { nid[tn[a]], nid[tn[b]], nid[tn[c]] })
		em:SetFaceColors(fid, { cid[tc[a]], cid[tc[b]], cid[tc[c]] })
		em:SetFaceUVs(fid, { uv0, uv0, uv0 })
	end
	return em
end

function M.upload(name, fidelity)
	local d = M.fetch(name)
	local em = M.build(d)
	local lastErr
	for _ = 1, 3 do
		local ok, res, id = pcall(function()
			local okA, assetId = AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = "RAH_" .. name, Description = "Run a Hotel prop" })
			assert(okA == Enum.CreateAssetResult.Success, "upload " .. tostring(okA))
			local part = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. assetId), { CollisionFidelity = fidelity or Enum.CollisionFidelity.Box })
			return part, assetId
		end)
		if ok then
			em:Destroy()
			res.Name = name
			res.Anchored = true
			res.PivotOffset = CFrame.new()
			res:SetAttribute("AssetId", id)
			return res
		end
		lastErr = res
		task.wait(1)
	end
	em:Destroy()
	error(name .. ": " .. tostring(lastErr))
end

-- Uploads every group of a prop into ServerStorage.HotelProps.<prop> (a Model, pivot = floor centre).
function M.prop(propName)
	local man = HttpService:JSONDecode(HttpService:GetAsync(M.BASE .. propName .. ".manifest.json"))
	local lib = game.ServerStorage:FindFirstChild("HotelProps") or Instance.new("Folder")
	lib.Name = "HotelProps"; lib.Parent = game.ServerStorage
	local model = Instance.new("Model")
	model.Name = propName
	for _, e in ipairs(man) do
		local p = M.upload(e.file)
		p.Name = e.group == "main" and "Body" or (e.group:sub(1,1):upper() .. e.group:sub(2))
		for k, v in pairs(M.LOOKS[e.group] or M.LOOKS.main) do p[k] = v end
		p:SetAttribute("Group", e.group)
		p.CFrame = CFrame.new()
		p.Parent = model
	end
	model.WorldPivot = CFrame.new()
	local old = lib:FindFirstChild(propName)
	if old then old:Destroy() end
	model.Parent = lib
	return model
end

return M
