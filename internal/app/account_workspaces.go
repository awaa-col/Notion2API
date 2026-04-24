package app

import (
	"fmt"
	"strings"
)

func normalizeWorkspaceItem(workspace NotionWorkspace) NotionWorkspace {
	workspace.ID = strings.TrimSpace(workspace.ID)
	workspace.ViewID = strings.TrimSpace(workspace.ViewID)
	workspace.Name = strings.TrimSpace(workspace.Name)
	workspace.PlanType = strings.TrimSpace(workspace.PlanType)
	return workspace
}

func mergeWorkspaceItem(base NotionWorkspace, extra NotionWorkspace) NotionWorkspace {
	base = normalizeWorkspaceItem(base)
	extra = normalizeWorkspaceItem(extra)
	if base.ID == "" {
		base.ID = extra.ID
	}
	if base.ViewID == "" {
		base.ViewID = extra.ViewID
	}
	if base.Name == "" {
		base.Name = extra.Name
	}
	if base.PlanType == "" {
		base.PlanType = extra.PlanType
	}
	base.AIEnabled = base.AIEnabled || extra.AIEnabled
	return base
}

func workspaceIdentity(workspace NotionWorkspace) string {
	workspace = normalizeWorkspaceItem(workspace)
	switch {
	case workspace.ID != "":
		return "id:" + strings.ToLower(workspace.ID)
	case workspace.ViewID != "":
		return "view:" + strings.ToLower(workspace.ViewID)
	case workspace.Name != "":
		return "name:" + strings.ToLower(workspace.Name)
	default:
		return ""
	}
}

func mergeWorkspaceLists(primary []NotionWorkspace, secondary []NotionWorkspace) []NotionWorkspace {
	out := make([]NotionWorkspace, 0, len(primary)+len(secondary))
	indexByIdentity := map[string]int{}
	appendWorkspace := func(workspace NotionWorkspace) {
		workspace = normalizeWorkspaceItem(workspace)
		if workspace.ID == "" && workspace.ViewID == "" && workspace.Name == "" {
			return
		}
		identity := workspaceIdentity(workspace)
		if idx, ok := indexByIdentity[identity]; ok {
			out[idx] = mergeWorkspaceItem(out[idx], workspace)
			return
		}
		if workspace.ID != "" {
			for idx, existing := range out {
				if strings.EqualFold(strings.TrimSpace(existing.ID), workspace.ID) {
					out[idx] = mergeWorkspaceItem(out[idx], workspace)
					indexByIdentity[workspaceIdentity(out[idx])] = idx
					return
				}
			}
		}
		out = append(out, workspace)
		indexByIdentity[identity] = len(out) - 1
	}
	for _, workspace := range primary {
		appendWorkspace(workspace)
	}
	for _, workspace := range secondary {
		appendWorkspace(workspace)
	}
	return out
}

func workspaceByID(workspaces []NotionWorkspace, workspaceID string) (NotionWorkspace, bool) {
	target := strings.TrimSpace(workspaceID)
	if target == "" {
		return NotionWorkspace{}, false
	}
	for _, workspace := range workspaces {
		if strings.EqualFold(strings.TrimSpace(workspace.ID), target) {
			return normalizeWorkspaceItem(workspace), true
		}
	}
	return NotionWorkspace{}, false
}

func workspaceScore(workspace NotionWorkspace) int {
	score := 0
	if workspace.AIEnabled {
		score += 2
	}
	if plan := strings.ToLower(strings.TrimSpace(workspace.PlanType)); plan != "" && plan != "free" {
		score++
	}
	if strings.TrimSpace(workspace.Name) != "" {
		score++
	}
	return score
}

func bestWorkspace(workspaces []NotionWorkspace) (NotionWorkspace, bool) {
	best := NotionWorkspace{}
	bestScore := -1
	for _, workspace := range workspaces {
		workspace = normalizeWorkspaceItem(workspace)
		if workspace.ID == "" {
			continue
		}
		score := workspaceScore(workspace)
		if score > bestScore {
			best = workspace
			bestScore = score
		}
	}
	if bestScore < 0 {
		return NotionWorkspace{}, false
	}
	return best, true
}

func selectPreferredWorkspace(workspaces []NotionWorkspace, preferredID string) (NotionWorkspace, bool) {
	if workspace, ok := workspaceByID(workspaces, preferredID); ok {
		return workspace, true
	}
	return bestWorkspace(workspaces)
}

func syncAccountToWorkspace(account NotionAccount, workspace NotionWorkspace) NotionAccount {
	workspace = normalizeWorkspaceItem(workspace)
	if workspace.ID != "" {
		account.SpaceID = workspace.ID
		account.ActiveWorkspaceID = workspace.ID
	}
	if workspace.ViewID != "" {
		account.SpaceViewID = workspace.ViewID
	}
	if workspace.Name != "" {
		account.SpaceName = workspace.Name
	}
	if workspace.PlanType != "" {
		account.PlanType = workspace.PlanType
	}
	return account
}

func normalizeAccountWorkspaceState(account NotionAccount) NotionAccount {
	account.ActiveWorkspaceID = strings.TrimSpace(account.ActiveWorkspaceID)
	legacyWorkspace := normalizeWorkspaceItem(NotionWorkspace{
		ID:       account.SpaceID,
		ViewID:   account.SpaceViewID,
		Name:     account.SpaceName,
		PlanType: account.PlanType,
	})
	account.Workspaces = mergeWorkspaceLists(account.Workspaces, []NotionWorkspace{legacyWorkspace})
	if account.ActiveWorkspaceID == "" {
		account.ActiveWorkspaceID = strings.TrimSpace(account.SpaceID)
	}
	if workspace, ok := selectPreferredWorkspace(account.Workspaces, account.ActiveWorkspaceID); ok {
		account = syncAccountToWorkspace(account, workspace)
		account.ActiveWorkspaceID = workspace.ID
		return account
	}
	account.SpaceID = strings.TrimSpace(account.SpaceID)
	account.SpaceViewID = strings.TrimSpace(account.SpaceViewID)
	account.SpaceName = strings.TrimSpace(account.SpaceName)
	account.PlanType = strings.TrimSpace(account.PlanType)
	return account
}

func accountActiveWorkspace(account NotionAccount) (NotionWorkspace, bool) {
	account = normalizeAccountWorkspaceState(account)
	if workspace, ok := workspaceByID(account.Workspaces, account.ActiveWorkspaceID); ok {
		return workspace, true
	}
	if workspace, ok := bestWorkspace(account.Workspaces); ok {
		return workspace, true
	}
	if strings.TrimSpace(account.SpaceID) == "" {
		return NotionWorkspace{}, false
	}
	return normalizeWorkspaceItem(NotionWorkspace{
		ID:       account.SpaceID,
		ViewID:   account.SpaceViewID,
		Name:     account.SpaceName,
		PlanType: account.PlanType,
	}), true
}

func setAccountActiveWorkspace(account NotionAccount, workspaceID string) (NotionAccount, error) {
	account = normalizeAccountWorkspaceState(account)
	workspace, ok := workspaceByID(account.Workspaces, workspaceID)
	if !ok {
		return account, fmt.Errorf("workspace %s not found for account", strings.TrimSpace(workspaceID))
	}
	account = syncAccountToWorkspace(account, workspace)
	account.ActiveWorkspaceID = workspace.ID
	return account, nil
}

func applyAccountWorkspaceToSession(account NotionAccount, session SessionInfo) SessionInfo {
	account = normalizeAccountWorkspaceState(account)
	if workspace, ok := accountActiveWorkspace(account); ok {
		session.SpaceID = firstNonEmpty(workspace.ID, session.SpaceID)
		session.SpaceViewID = firstNonEmpty(workspace.ViewID, session.SpaceViewID)
		session.SpaceName = firstNonEmpty(workspace.Name, session.SpaceName)
	}
	session.UserName = firstNonEmpty(account.UserName, session.UserName)
	return session
}

func mergeAccountWorkspaces(account NotionAccount, workspaces []NotionWorkspace, preferredID string) NotionAccount {
	account.Workspaces = mergeWorkspaceLists(workspaces, account.Workspaces)
	if strings.TrimSpace(preferredID) != "" {
		account.ActiveWorkspaceID = strings.TrimSpace(preferredID)
	}
	return normalizeAccountWorkspaceState(account)
}
