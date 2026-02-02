@attached(peer, names: prefixed(_SkillsBarDescriptorRegistration_))
public macro ProviderDescriptorRegistration() = #externalMacro(
    module: "SkillsBarMacros",
    type: "ProviderDescriptorRegistrationMacro")

@attached(member, names: named(descriptor))
public macro ProviderDescriptorDefinition() = #externalMacro(
    module: "SkillsBarMacros",
    type: "ProviderDescriptorDefinitionMacro")

@attached(peer, names: prefixed(_SkillsBarImplementationRegistration_))
public macro ProviderImplementationRegistration() = #externalMacro(
    module: "SkillsBarMacros",
    type: "ProviderImplementationRegistrationMacro")
