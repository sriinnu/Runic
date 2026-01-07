@attached(peer, names: prefixed(_RunicDescriptorRegistration_))
public macro ProviderDescriptorRegistration() = #externalMacro(
    module: "RunicMacros",
    type: "ProviderDescriptorRegistrationMacro")

@attached(member, names: named(descriptor))
public macro ProviderDescriptorDefinition() = #externalMacro(
    module: "RunicMacros",
    type: "ProviderDescriptorDefinitionMacro")

@attached(peer, names: prefixed(_RunicImplementationRegistration_))
public macro ProviderImplementationRegistration() = #externalMacro(
    module: "RunicMacros",
    type: "ProviderImplementationRegistrationMacro")
