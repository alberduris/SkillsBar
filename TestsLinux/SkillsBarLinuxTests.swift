import Foundation
import Testing
@testable import SkillsBarCore

@Suite("Linux Platform Tests")
struct LinuxPlatformTests {
    @Test("Core models work on Linux")
    func coreModelsWork() {
        let agent = AgentRegistry.defaultAgent
        #expect(agent.id == "claude")
        #expect(agent.configDirName == ".claude")
    }

    @Test("SkillSource enum works")
    func skillSourceWorks() {
        #expect(SkillSource.global.displayName == "Global")
        #expect(SkillSource.allCases.count == 3)
    }
}
