import Foundation

enum StarterLibrary {
    static func make() -> NoteLibrary {
        let personal = Notebook(name: "Personal", symbol: "leaf", colorIndex: 0)
        let work = Notebook(name: "Work", symbol: "briefcase", colorIndex: 1)
        let ideas = Notebook(name: "Ideas", symbol: "lightbulb", colorIndex: 2)
        let welcome = Note(title: "A little room to think.", text: "Welcome to BetterNote.\n\nA quieter place for your thoughts, plans, and the things you don't want to forget. Make yourself at home.\n\nSTART WITH A THOUGHT\n\nWrite freely. Your notes save automatically on this Mac, so you can stay in the moment. Select text to make it bold, italic, or highlight something worth remembering.\n\nMAKE IT YOURS\n\n☐ Create your first note with ⌘N\n☐ Give it a home in a notebook\n☐ Add a tag to connect your ideas\n☐ Try Focus mode with ⇧⌘F\n\nA SPACE THAT STAYS WITH YOU\n\nPin the important things. Find a thought instantly. Export a note when it's ready to leave your desk.\n\nYour next good idea starts here.", notebookID: personal.id, tags: ["welcome", "getting-started"], isPinned: true)
        let notes = [welcome,
            Note(title: "Small things, good days", text: "A walk without headphones.\nCoffee before the inbox.\nA book with a folded corner.\n\nMore of this, please.", notebookID: personal.id, tags: ["life"]),
            Note(title: "Monday, with intention", text: "This week's focus\n\n☐ Make space for deep work\n☐ Finish the first draft\n☐ Send the project update\n\nOne meaningful thing at a time.", notebookID: work.id, tags: ["planning"], isPinned: true),
            Note(title: "What if we made it simpler?", text: "The best tools get out of the way.\n\nAn idea: a workspace that feels like opening a fresh notebook. A little structure, a lot of possibility.\n\nExplore\n• Fewer decisions before you can start\n• Thoughtful defaults\n• Details that feel human", notebookID: ideas.id, tags: ["design", "ideas"]),
            Note(title: "Places for a slow weekend", text: "Somewhere near the water.\nA small café with big windows.\nA path we haven't walked before.\n\nNo itinerary required.", notebookID: personal.id, tags: ["travel"])
        ]
        return NoteLibrary(notebooks: [personal, work, ideas], notes: notes)
    }
}
