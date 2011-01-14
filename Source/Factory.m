#import "Factory.h"
#import "ClassAnalyzer.h"
#import "ClassProperty.h"

@interface Factory ()
@property(retain) ClassAnalyzer *analyzer;
@property(retain) NSMutableDictionary *components;
@property(retain) NSMutableSet *singletons;
@end

@implementation Factory
@synthesize analyzer, components, singletons;

- (id) init
{
    [super init];
    analyzer = [[ClassAnalyzer alloc] init];
    components = [[NSMutableDictionary alloc] init];
    singletons = [[NSMutableSet alloc] init];
    return self;
}

- (void) dealloc
{
    [analyzer release];
    [singletons release];
    [components release];
    [super dealloc];
}

- (Component*) addComponent: (Class) componentType
{
    id component = [Component componentWithClass:componentType];
    [components setObject:component forKey:componentType];
    return component;
}

- (void) addSingleton: (id) singleton
{
    [singletons addObject:singleton];
}

- (void) wire: (id) instance
{
    // Fill dependencies
    NSArray *properties = [analyzer propertiesOf:[instance class]];
    for (ClassProperty *property in properties)
    {
        // Skip RO properties.
        if ([property isReadOnly])
            continue;
        // Skip property if already connected.
        if ([instance valueForKey:[property name]] != nil)
            continue;
        id dependency = [self assemble:[property classType]];
        [instance setValue:dependency forKey:[property name]];
    }

    // Call the post-assembly hook if component supports it
    SEL postAssemblyHook = @selector(afterAssembling);
    if ([instance respondsToSelector:postAssemblyHook])
        [instance performSelector:postAssemblyHook];
}

- (id) assemble: (Class) compType
{
    // The factory is a special kind of dependency, too.
    if ([self isMemberOfClass:compType])
        return self;

    // Try to find a singleton first.
    for (id singleton in singletons)
        if ([singleton isMemberOfClass:compType])
            return singleton;

    // Create and wire new component instance.
    // Will return nil for unknown components.
    id instance = [[components objectForKey:compType] newInstance];
    [self wire:instance];
    return instance;
}

@end
