Use (Swipe Actions) with these refinements:

Swipe Menu Structure:
text
Swipe Left (destructive side):
├── [Pin/Unpin] - Blue, prominent
├── [Edit] - Gray
└── [Delete] - Red (rightmost, dangerous)
Home View Integration:
Pinned card shows: Small 📌 badge in top-right corner

Home view: Shows pinned items in a grid or list with clear "Pinned" section header

Empty state: "Pin content from Library to customize your home view"

Implementation Details for iOS
1. Swipe Actions Code Pattern:
swift
// Add leading swipe action for Pin/Unpin
func tableView(_ tableView: UITableView, 
               trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) 
    -> UISwipeActionsConfiguration? {
    
    let item = items[indexPath.row]
    
    // Pin action
    let pinAction = UIContextualAction(style: .normal, title: "Pin") { _, _, complete in
        viewModel.togglePin(item: item)
        complete(true)
    }
    pinAction.backgroundColor = UIColor.systemBlue
    
    // Edit action
    let editAction = UIContextualAction(style: .normal, title: "Edit") { _, _, complete in
        // Navigate to edit
        complete(true)
    }
    editAction.backgroundColor = UIColor.systemGray
    
    // Delete action
    let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, complete in
        viewModel.delete(item: item)
        complete(true)
    }
    
    let config = UISwipeActionsConfiguration(actions: [deleteAction, editAction, pinAction])
    config.performsFirstActionWithFullSwipe = false
    return config
}
2. Visual Feedback:
✅ Haptic feedback on pin action: UIImpactFeedbackGenerator(style: .light).impactOccurred()

✅ Toast notification: "Added to Home" / "Removed from Home" (2 seconds)

✅ Badge animation: Small pin icon animates in when pinned

3. State Management:
swift
// Model
struct LibraryItem {
    var id: UUID
    var title: String
    var isPinned: Bool = false
    var pinnedOrder: Int? // For sorting on Home
}

// ViewModel
func togglePin(item: LibraryItem) {
    var updated = item
    updated.isPinned.toggle()
    updated.pinnedOrder = updated.isPinned ? 
        (maxPinnedOrder + 1) : nil
    
    repository.update(updated)
    hapticFeedback.play(.light)
    showToast("Updated")
}
Home View Design
text
┌─────────────────────┐
│ 📌 Pinned Content   │
├─────────────────────┤
│ [Card 1] [Card 2]  │
│ [Card 3] [Card 4]  │
├─────────────────────┤
│ 📚 All Content      │
├─────────────────────┤
│ [Show all content]  │
└─────────────────────┘
Accessibility Considerations
VoiceOver: Swipe menu should be announced as "Pin, double tap to activate"

Haptics: Critical for users who miss visual feedback

Alternative: Offer long-press as fallback for users who struggle with swipes

Pro Tips from Experience
Gotcha	Solution
Users miss the swipe gesture	Add tutorial animation first time viewing Library
Pinned items feel "stuck"	Show clear visual feedback (badge + highlight animation)
Too many pinned items	Cap at 5-8 items, show warning "Home view is full"
Unpinning is annoying	Show "Pin/Unpin" toggle button in both directions
No undo after delete	Implement soft delete or undo toast (3-5 sec window)