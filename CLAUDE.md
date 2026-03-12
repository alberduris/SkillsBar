After every code change, build and deploy: `swift build && cp .build/arm64-apple-macosx/debug/SkillsBar SkillsBar.app/Contents/MacOS/SkillsBar && killall SkillsBar 2>/dev/null; sleep 0.5 && open SkillsBar.app` — then tell the user it's ready to test.
Read logs: `/usr/bin/log show --last <Nm> --predicate 'subsystem BEGINSWITH "com.skillsbar"' --debug --info`
