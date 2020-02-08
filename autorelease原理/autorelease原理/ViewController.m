//
//  ViewController.m
//  autorelease原理
//
//  Created by 赵鹏 on 2019/8/27.
//  Copyright © 2019 赵鹏. All rights reserved.
//

/**
 为了营造MRC环境，先要在TARGETS中的Build Settings中把ARC由YES改为NO；
 
 可以参考day24中的《内存布局》Demo中的内容：
 1、内存布局：
 内存地址由低到高依次为：
（1）保留段：这块区域一般不放任何东西，是给系统保留的；
（2）代码段(__TEXT)：这块区域一般用来存放编译之后的代码(010101......之类的二进制代码)；
（3）数据段(__DATA)：这块区域一般会按由低地址到高地址的顺序存放如下的内容：
 ①字符串常量：比如NSString *str = @"123"；
 ②已初始化的数据：已初始化的全局变量、静态变量等；
 ③未初始化的数据：未初始化的全局变量、静态变量等。
（4）堆：通过alloc、malloc、calloc等方法动态分配内存空间。在分配内存地址的时候一般是按照内存地址由小到大的原则进行分配的；
（5）栈：这块区域一般用来存放程序中的局部变量。在存放的时候一般是按照内存地址由大到小的原则进行存放的，即把先遇到的局部变量存放为大的内存地址，后遇到的局部变量存放为小的内存地址；
（6）内核区。
 
 2、Tagged Pointer：
（1）从64bit开始，iOS引入了Tagged Pointer技术，用于优化NSNumber、NSDate、NSString等小对象的存储；
（2）在没有使用Tagged Pointer之前，NSNumber等对象需要动态分配内存、维护引用计数等。NSNumber指针存储的是堆中NSNumber对象的地址值；
（3）使用Tagged Pointer之后，NSNumber指针里面存储的数据变成了：Tag（标记） + Data，也就是将数据直接存储在了指针中；
（4）当指针不够存储数据时，才会使用动态分配内存的方式来存储数据了；
（5）objc_msgSend能识别Tagged Pointer，比如"objc_msgSend(number, @selector(intValue));"，objc_msgSend函数会直接从指针提取数据，节省了以前的调用开销。
  
 可以参考day25中的《内存管理》Demo中的内容：
 在MRC环境下：
 1、在iOS中，使用引用计数来管理OC对象的内存；
 2、一个新创建的OC对象的引用计数默认是1，当它的引用计数减为0的时候，该对象就会被系统销毁掉，然后释放其占用的内存空间；
 3、调用"retain"方法会让OC对象的引用计数+1，调用"release"方法会让OC对象的引用计数-1；
 4、当调用alloc、new、copy、mutableCopy等方法返回了一个对象，在不需要这个对象时，开发者要主动调用release或者autorelease方法来释放它；
 5、想拥有某个对象，就让它的引用计数+1；不想再拥有某个对象，就让它的引用计数-1；
 6、内存泄露：因为iOS项目是RunLoop运行循环，如果用完了对象而在代码中不做销毁操作的话，这个对象的内存空间是始终存在的，除非这个项目被手动杀死。如果该项目不被手动杀死的话，则这个项目是始终存在的，所以这个对象也会始终存在，则这个对象所对应的那片内存空间也是始终存在的，随着程序的运行，像这种的对象会越积越多，就会有很多的内存不被释放，这种现象叫做“内存泄露”。
  
 可以参考day26中的《weak指针原理》Demo的内容：
 ARC是LLVM编译器和Runtime运行时相互协作的一个结果，首先ARC利用LLVM编译器自动生成release、retain、autorelease等在MRC中需要用到的代码。其次，对于"__weak"类型的弱指针而言，在Runtime运行的过程中当监控到某个对象被销毁的时候，会把这个对象对应的弱引用置为nil。
 
 引用计数的存储：
 1、在arm64架构之前，isa就是一个普通的指针，它存储着Class对象、Meat-Class对象的内存地址；
 2、从arm64架构开始，对isa就进行了优化，变成了一个共用体(union)结构，这个共用体结构里面的每个元素被称为一个位域，可以利用位域来存储更多的信息。可以把这个共用体结构看成是一个类似于结构体(struct)的东西，结构体里面的每个元素可以看成是上述的每个位域；
 3、在64bit中，对象的引用计数可以直接存储在优化过的isa指针中的某个位域中，也可以存储在SideTable类中。当对象的引用计数存储在isa指针中的时候，其实是存储在这个共用体结构中的extra_rc这个位域中的，这个位域中存储的值是对象的引用计数减1以后的值（比如对象的引用计数为3，则它存储的是2这个值）。如果对象引用计数的值过大就无法存储在isa中了，则isa共用体中的has_sidetable_rc这个位域就变为了1，那么对象的引用计数就会存储在一个叫做SideTable类的属性中了；
 4、SideTable类是一个结构体，里面包含三个元素，spinlock_t slock、RefcountMap refcnts和weak_table_t weak_table。当isa不够存储对象的引用计数的时候，则引用计数就会存储在SideTable结构体中的"RefcountMap refcnts"元素中，这个元素其实就是一个存放着对象引用计数的散列表。
 */
#import "ViewController.h"
#import "ZPPerson.h"

extern void _objc_autoreleasePoolPrint(void);  //这是一个私有方法，用来查看自动释放池里面的内存情况的。在代码中引用之前需要先在外面用extern关键字引用一下才可以。

@interface ViewController ()

@end

@implementation ViewController

#pragma mark ————— 生命周期 —————
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self test];
    
//    [self test1];
    
//    [self test2];
}

- (void)test
{
    /**
     在MRC环境下，有的时候autorelease方法和外面的"@autoreleasepool"关键字还有大括号联合使用，如本方法所示。
    
     autorelease和release方法的区别：release方法是在开发者创建了新的实例对象以后，要开发者确定这个新对象不用了之后再进行调用，从而释放新对象的内存空间。而autorelease方法是在开发者一开始创建新的实例对象的时候就进行调用，创建以后就不用随时关心什么时候该对象彻底就不用了，系统会在"@autoreleasepool"最后一个大括号结束的时候统一调用release方法来释放该对象的内存空间。
     
     在终端中利用命令行语句把本文件编译为.cpp(C++)文件以后就可以看到
     __AtAutoreleasePool（自动释放池）实际上就是一个结构体：
     struct __AtAutoreleasePool
     {
         __AtAutoreleasePool()  //构造函数，在创建结构体的时候会被调用
         {
            atautoreleasepoolobj = objc_autoreleasePoolPush();
         }
     
         ~__AtAutoreleasePool()  //析构函数，在销毁结构体的时候会被调用
         {
            objc_autoreleasePoolPop(atautoreleasepoolobj);
         }
     
         void * atautoreleasepoolobj;
     };
     
     同时还可以看到下面的"@autoreleasepool{...}"这段代码被编译如下：
     {
     __AtAutoreleasePool __autoreleasepool; //声明一个结构体变量（同时也是一个局部变量）。会调用上述结构体中的构造函数"atautoreleasepoolobj = objc_autoreleasePoolPush();"
     ZPPerson *person = ((ZPPerson *(*)(id, SEL))(void *)objc_msgSend)((id)((ZPPerson *(*)(id, SEL))(void *)objc_msgSend)((id)((ZPPerson *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("ZPPerson"), sel_registerName("alloc")), sel_registerName("init")), sel_registerName("autorelease"));
     }  //因为在大括号内构造的"__AtAutoreleasePool __autoreleasepool;"是一个局部变量，所以当出了这个大括号之后就会调用上述结构体中的析构函数"objc_autoreleasePoolPop(atautoreleasepoolobj);"来把这个局部变量进行销毁。
     */
    @autoreleasepool {
        /**
         从上述的源码分析中可以看出，在MRC环境下，当执行@autoreleasepool大括号内的代码时首先会调用构造函数"atautoreleasepoolobj = objc_autoreleasePoolPush();"来创建一个结构体变量"__AtAutoreleasePool __autoreleasepool;"，可以把它看成是一个自动释放池，然后再执行下面的创建实例对象的代码。
         
         又可以从Runtime的源代码中看出构造函数"atautoreleasepoolobj = objc_autoreleasePoolPush();"和析构函数"objc_autoreleasePoolPop(atautoreleasepoolobj);"的底层主要结构是"__AtAutoreleasePool"和"AutoreleasePoolPage"类，所以可以说当某个对象调用autorelease函数最终都是通过AutoreleasePoolPage类来进行管理的。
         
         AutoreleasePoolPage：
         1、内部结构：当调用构造函数"atautoreleasepoolobj = objc_autoreleasePoolPush();"的时候就会创建一个AutoreleasePoolPage对象，这个对象占用4096字节的内存空间。可以把该对象想象成一个栈空间，这个栈的上面几层用来存放AutoreleasePoolPage类的成员变量，下面几层用来存放调用autorelease函数的那个实例对象的内存地址值，即下面新创建的person对象的内存地址值；
         2、存放过程：
         （1）当系统调用构造函数"atautoreleasepoolobj = objc_autoreleasePoolPush();"的时候，系统首先会把一个值为nil，名为"POOL_BOUNDARY"（译为边界）的宏压入到栈中，存放在栈里面那些预留的空位置的第一层中，并且返回其存放的地址值，所以atautoreleasepoolobj = “存放POOL_BOUNDARY的地址值”。后面就是下面的创建实例对象并调用autorelease函数的代码了，系统会把这些调用autorelease函数的实例对象的地址值按照调用的顺序一个接一个地存放在栈中的POOL_BOUNDARY层的下面几层中；
         （2）在程序运行的过程中可能会有多个实例对象来调用autorelease函数，如果一个AutoreleasePoolPage对象存放不开的话，系统就会创建一个新的AutoreleasePoolPage对象来继续存放，直到全部存放完了为止，这些AutoreleasePoolPage对象是通过双向链表的形式连接在一起的。
         3、释放过程：当出了大括号的时候就会调用析构函数"objc_autoreleasePoolPop(atautoreleasepoolobj);"，这个小括号里面的atautoreleasepoolobj其实就是存储POOL_BOUNDARY的地址值。系统先会把上面创建的结构体变量"__AtAutoreleasePool __autoreleasepool;"（自动释放池）销毁掉，然后系统会根据POOL_BOUNDARY的地址值找到最后一个压入到栈中的那个实例对象的内存地址值（栈中存储实例对象内存地址的最后一个格子），然后再从下往上逐个调用他们的release方法，挨个释放掉他们，直到遇到POOL_BOUNDARY为止。
         */
        ZPPerson *person = [[[ZPPerson alloc] init] autorelease];
        
        _objc_autoreleasePoolPrint();  //查看自动释放池里面的情况
    }
    
    /**
     当出了这个大括号的时候，系统就会调用析构函数"objc_autoreleasePoolPop(atautoreleasepoolobj);"先把上面创建的结构体变量"__AtAutoreleasePool __autoreleasepool;"（自动释放池）销毁掉。然后会根据之前存储在AutoreleasePoolPage对象中的那些地址值找到调用autorelease函数的那些具体的对象，给这些对象逐一地调用release函数，把他们全部都释放掉。
     */
    
    /**
     总结：在MRC环境下，当执行@autoreleasepool大括号内的代码的时首先会调用构造函数"atautoreleasepoolobj = objc_autoreleasePoolPush();"来创建一个结构体变量"__AtAutoreleasePool __autoreleasepool;"，可以把这个结构体变量看成是一个自动释放池，同时也会创建一个"AutoreleasePoolPage"对象，这个对象共有4096字节的内存，可以把它看成是一个栈结构，这个栈的上面几层存储的是它的成员变量，然后再把一个名为"POOL_BOUNDARY"（译为边界）的宏压入到这个栈中，并返回它的地址值，这个栈的下面几层空间先预留出来。然后系统会继续执行后面创建实例对象的代码，当创建出来的实例对象调用autorelease方法的时候，系统就会按照执行顺序把这些实例对象的内存地址按照“先进后出”的原则逐一的压入到"AutoreleasePoolPage"这个对象的栈中，是接着"POOL_BOUNDARY"下面的空间压入的。如果一个AutoreleasePoolPage对象存放不开的话，系统就会创建一个新的AutoreleasePoolPage对象继续存放他们，直到把这些实例对象的地址值全部存放完了为止。这些AutoreleasePoolPage对象是通过双向链表的形式连接在一起的。当出了这个大括号的时候，系统就会调用析构函数"objc_autoreleasePoolPop(atautoreleasepoolobj);"，系统首先会把一开始创建的结构体变量"__AtAutoreleasePool __autoreleasepool;"（自动释放池）销毁掉，然后找到之前储存POOL_BOUNDARY的地址值，根据这个地址值找到最后一个压入到栈中的那个实例对象的内存地址值（栈中存储实例对象的内存地址的最后一个格子），然后再从下往上逐个调用他们的release方法，挨个释放掉他们，直到遇到POOL_BOUNDARY为止。上述就是针对"@autoreleasepool{...}"这段代码的内部运行原理的剖析。
     */
}

- (void)test1
{
    /**
     在MRC环境中，在实例对象调用autorelease方法的时候关于何时该实例对象被调用release方法，从而被释放掉，分为以下的两种情况：
     1、@autoreleasepool
            {
                ZPPerson *person = [[[ZPPerson alloc] init] autorelease];
            }
     这种方式的释放原理见test方法所述。
     2、直接撰写下面的创建实例对象的代码，直接调用autorelease方法，没有外面的"@autoreleasepool"关键字和大括号。
     在控制台中把当前的RunLoop对象打印出来之后可以看到iOS在主线程的Runloop中注册了2个Observer：
     （1）"<CFRunLoopObserver 0x6000005c4640 [0x7fff80617cb0]>{valid = Yes, activities = 0x1, repeats = Yes, order = -2147483647, callout = _wrapRunLoopWithAutoreleasePoolHandler (0x7fff4808bf54), context = <CFArray 0x600003a9dda0 [0x7fff80617cb0]>{type = mutable-small, count = 1, values = (\n\t0 : <0x7f8638806048>\n)}}"
     根据它里面的"activities = 0x1"可以确定这个Observer是用来监听kCFRunLoopEntry状态的，即监听RunLoop刚刚进入的这个状态的。当Observer监听到这个状态的时候，系统就会调用构造函数"objc_autoreleasePoolPush();"；
     （2）"<CFRunLoopObserver 0x6000005c46e0 [0x7fff80617cb0]>{valid = Yes, activities = 0xa0, repeats = Yes, order = 2147483647, callout = _wrapRunLoopWithAutoreleasePoolHandler (0x7fff4808bf54), context = <CFArray 0x600003a9dda0 [0x7fff80617cb0]>{type = mutable-small, count = 1, values = (\n\t0 : <0x7f8638806048>\n)}}"
     根据它里面的"activities = 0xa0"可以确定这个Observer是用来监听kCFRunLoopBeforeWaiting和kCFRunLoopExit状态的，即监听RunLoop即将进入休眠状态和退出状态的。当Observer监听到RunLoop即将进入休眠状态(kCFRunLoopBeforeWaiting)的时候，系统先会调用析构函数"objc_autoreleasePoolPop();"，然后再调用构造函数"objc_autoreleasePoolPush();"。当Observer监听到RunLoop即将进入退出状态(kCFRunLoopExit)的时候，系统会直接调用析构函数"objc_autoreleasePoolPop();"。
     
     针对2这种情况的总结：
     ①当刚刚进入RunLoop的运行循环中的时候，当前RunLoop的Observer对象就会监听到，然后系统会调用构造函数"objc_autoreleasePoolPush();"创建一个结构体变量"__AtAutoreleasePool __autoreleasepool;"，可以把它看成是一个自动释放池，同时也创建了"AutoreleasePoolPage"对象，这个对象共有4096字节的内存，可以把它看成是一个栈结构，这个栈的上面几层存储的是它的成员变量，然后再把一个名为"POOL_BOUNDARY"（译为边界）的宏压入到这个栈中，并返回它的地址值，这个栈的下面几层的空间先预留出来。然后系统会把调用autorelease函数的实例对象的内存地址按照“先进后出”的原则逐一的压入到"AutoreleasePoolPage"这个对象的栈中，是接着"POOL_BOUNDARY"下面的空间压入的。如果一个AutoreleasePoolPage对象存放不开的话，系统就会创建一个新的AutoreleasePoolPage对象来继续存放他们，直到把这些实例对象的内存地址全部存放完了为止。这些AutoreleasePoolPage对象是通过双向链表的形式连接在一起的。
     ②当当前RunLoop的Observer对象监听到RunLoop即将进入休眠状态的时候，系统首先会调用析构函数"objc_autoreleasePoolPop();"把一开始创建的结构体变量"__AtAutoreleasePool __autoreleasepool;"（自动释放池）销毁掉，并且找到之前储存POOL_BOUNDARY的地址值，然后根据这个地址值找到最后一个压入到栈中的那个实例对象的内存地址值（栈中存储实例对象的内存地址的最后一个格子），然后再从下往上逐个调用他们的release方法，挨个释放掉他们，直到遇到POOL_BOUNDARY为止。等做完上述的操作之后，然后系统就会调用构造函数"objc_autoreleasePoolPush();"再一次重复上面①中的步骤，然后RunLoop再继续进行循环；
     ③当RunLoop的Observer对象监听到RunLoop即将进入退出状态的时候，系统就会调用析构函数"objc_autoreleasePoolPop();"把之前创建的结构体变量"__AtAutoreleasePool __autoreleasepool;"（自动释放池）销毁掉，并且找到之前储存POOL_BOUNDARY的地址值，然后根据这个地址值找到最后一个压入到栈中的那个实例对象的内存地址值（栈中存储实例对象的内存地址的最后一个格子），然后再从下往上逐个调用他们的release方法，挨个释放掉他们，直到遇到POOL_BOUNDARY为止。这样整个RunLoop循环才算完成。
    
     综上所述，在MRC环境下，如上述的2情况中直接撰写下面的创建实例对象的代码，在创建之后这个实例对象什么时候被释放其实是由RunLoop来进行控制的，在它所属的那次的RunLoop运行循环中，在进入到休眠状态之前或者即将进入退出状态的时候就会调用这个实例对象的release方法来彻底释放他们。
     */
    ZPPerson *person = [[[ZPPerson alloc] init] autorelease];
    
    NSLog(@"%@", [NSRunLoop mainRunLoop]);
}

- (void)test2
{
    ZPPerson *person = [[ZPPerson alloc] init];
    
    /**
     在ARC环境中，开发者一般撰写上面的一句代码来创建一个实例对象之后就不用管它什么时候被释放了，释放过程由系统来完成。一般情况下系统会在合适的地方自动添加相关的释放代码。根据编译器的不同，添加的方式主要有如下的两种：
     1、添加"autorelease"方法(ZPPerson *person = [[[ZPPerson alloc] init] autorelease];)，释放原理如上面的test1方法中所述；
     2、添加"release"方法：在上面一句代码之后并且在确定不再使用该对象的时候，系统会新添加一句"[person release];"代码，如下行所示，对该对象调用release方法，从而释放掉它。
     */
    
    [person release];
}

/**
 综合上面所述：
 1、在MRC环境下，有两种写法：
 （1）@autoreleasepool{
            ZPPerson *person = [[[ZPPerson alloc] init] autorelease];
     }
 
 （2）ZPPerson *person = [[[ZPPerson alloc] init] autorelease];
 2、在ARC环境下，在开发者撰写"ZPPerson *person = [[ZPPerson alloc] init];"语句创建实例对象以后，根据编译器的不同，系统会在合适的地方自动添加相关的释放代码，主要有如下的两种写法：
 （1）ZPPerson *person = [[[ZPPerson alloc] init] autorelease];
 
 （2）ZPPerson *person = [[ZPPerson alloc] init];
     [person release];
 */

@end
