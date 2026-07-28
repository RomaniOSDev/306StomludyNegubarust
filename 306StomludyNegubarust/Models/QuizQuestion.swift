import Foundation

struct QuizQuestion: Identifiable, Equatable {
    let id: UUID
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let topicTitle: String

    init(
        id: UUID = UUID(),
        prompt: String,
        choices: [String],
        correctIndex: Int,
        topicTitle: String
    ) {
        self.id = id
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
        self.topicTitle = topicTitle
    }
}
