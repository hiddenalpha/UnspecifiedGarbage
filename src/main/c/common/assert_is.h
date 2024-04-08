
#if !NDEBUG
#define TPL_assert_is(T, PRED) static inline T*assert_is_##T(void*p,\
const char*f,int l){if(p==NULL){fprintf(stderr,"assert(" STR_QUOT(T)\
" != NULL)  %s:%d\n",f,l);abort();}T*obj=p;if(!PRED){fprintf(stderr,\
"ssert(type is \""STR_QUOT(T)"\")  %s:%d\n",f,l);abort();}return p; }
#else
#define TPL_assert_is(T, PRED) static inline T*assert_is_##T(void*p,\
const char*f,int l){return p;}
#endif



/* Example usage: */

/* add some magic to your struct under check */
typedef  struct Person  Person;
struct Person {
    char tYPE[sizeof"Hi, I'm a Person"];
};

/* instantiate a checker */
TPL_assert_is(Person, !strcmp(obj->tYPE, "Hi, I'm a Person"));
#define assert_is_Person(p) assert_is_Person(p, __FILE__, __LINE__)

/* make sure magic is initialized (ALSO MAKE SURE TO PROPERLY INVALIDATE
 * IT IN DTOR!)*/
static void someCaller( void ){
    Person p = {0};
    strcpy(p.tYPE, "Hi, I'm a Person");
    void *ptr = p; /*whops compiler cannot help us any longer*/
    someCallee(ptr);
}

/* verify you reall got a Person*/
static void someCallee( void*shouldBeAPerson ){
    Person *p = assert_is_Person(shouldBeAPerson);
}

