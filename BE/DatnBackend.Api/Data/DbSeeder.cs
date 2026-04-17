using DatnBackend.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace DatnBackend.Api.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(AppDbContext db)
    {
        if (await db.Topics.AnyAsync()) return; // Đã có data thì bỏ qua

        var now = DateTime.UtcNow;

        // ── Topics ────────────────────────────────────────────────────────────
        var topics = new List<Topic>
        {
            new() { Id = "topic-java-basics",      Title = "Java Cơ Bản",                   Description = "Biến, kiểu dữ liệu, toán tử, vòng lặp và cấu trúc điều kiện trong Java.",          Icon = "☕", Color = "#F89820", Order = 1, TotalLessons = 4, IsActive = true, CreatedAt = now },
            new() { Id = "topic-oop",              Title = "Lập Trình Hướng Đối Tượng",      Description = "Class, Object, kế thừa, đa hình, đóng gói và trừu tượng hóa.",                     Icon = "🧱", Color = "#4A90D9", Order = 2, TotalLessons = 4, IsActive = true, CreatedAt = now },
            new() { Id = "topic-collections",      Title = "Collections & Generics",         Description = "List, Set, Map, Queue và cách sử dụng Generics hiệu quả.",                          Icon = "📦", Color = "#7B68EE", Order = 3, TotalLessons = 3, IsActive = true, CreatedAt = now },
            new() { Id = "topic-exception",        Title = "Xử Lý Ngoại Lệ",                Description = "try-catch-finally, checked/unchecked exceptions và custom exception.",               Icon = "⚠️", Color = "#E74C3C", Order = 4, TotalLessons = 3, IsActive = true, CreatedAt = now },
            new() { Id = "topic-streams",          Title = "Stream API & Lambda",            Description = "Lập trình hàm trong Java với Stream, Lambda expression và Method reference.",        Icon = "🌊", Color = "#1ABC9C", Order = 5, TotalLessons = 3, IsActive = true, CreatedAt = now },
        };

        // ── Lessons ───────────────────────────────────────────────────────────
        var lessons = new List<Lesson>
        {
            // Java Cơ Bản
            new() { Id = "lesson-jb-1", TopicId = "topic-java-basics", Title = "Biến và Kiểu Dữ Liệu", Order = 1, XpReward = 10, EstimatedMinutes = 10, IsActive = true, CreatedAt = now,
                Summary = "Tìm hiểu các kiểu dữ liệu nguyên thủy và cách khai báo biến trong Java.",
                Content = """
## Biến và Kiểu Dữ Liệu trong Java

Java là ngôn ngữ **kiểu tĩnh** (statically typed), nghĩa là mỗi biến phải được khai báo kiểu dữ liệu trước khi sử dụng.

### Kiểu dữ liệu nguyên thủy (Primitive Types)

| Kiểu    | Kích thước | Ví dụ              |
|---------|------------|---------------------|
| `int`   | 32-bit     | `int age = 25;`     |
| `long`  | 64-bit     | `long big = 100L;`  |
| `double`| 64-bit     | `double pi = 3.14;` |
| `float` | 32-bit     | `float f = 1.5f;`   |
| `char`  | 16-bit     | `char c = 'A';`     |
| `boolean`| 1-bit   | `boolean ok = true;`|
| `byte`  | 8-bit      | `byte b = 127;`     |
| `short` | 16-bit     | `short s = 1000;`   |

### Khai báo và khởi tạo biến

```java
int x = 10;
String name = "Java";
final double PI = 3.14159; // hằng số
```

### Kiểu tham chiếu (Reference Types)

`String`, mảng và các object đều là kiểu tham chiếu — lưu địa chỉ bộ nhớ thay vì giá trị trực tiếp.

```java
String s1 = "Hello";
String s2 = s1; // s2 trỏ cùng object
```
""" },

            new() { Id = "lesson-jb-2", TopicId = "topic-java-basics", Title = "Toán Tử và Biểu Thức", Order = 2, XpReward = 10, EstimatedMinutes = 10, IsActive = true, CreatedAt = now,
                Summary = "Các toán tử số học, so sánh, logic và ưu tiên toán tử.",
                Content = """
## Toán Tử trong Java

### Toán tử số học
```java
int a = 10, b = 3;
System.out.println(a + b);  // 13
System.out.println(a - b);  // 7
System.out.println(a * b);  // 30
System.out.println(a / b);  // 3 (chia nguyên)
System.out.println(a % b);  // 1 (chia lấy dư)
```

### Toán tử so sánh
```java
a == b   // false
a != b   // true
a > b    // true
a >= b   // true
```

### Toán tử logic
```java
true && false  // false (AND)
true || false  // true  (OR)
!true          // false (NOT)
```

### Toán tử tăng/giảm
```java
int x = 5;
x++;  // x = 6 (hậu tố)
++x;  // x = 7 (tiền tố)
x--;  // x = 6
```

### Toán tử tam phân (Ternary)
```java
int max = (a > b) ? a : b; // 10
```
""" },

            new() { Id = "lesson-jb-3", TopicId = "topic-java-basics", Title = "Câu Lệnh Điều Kiện", Order = 3, XpReward = 10, EstimatedMinutes = 12, IsActive = true, CreatedAt = now,
                Summary = "if-else, switch-case và cách sử dụng trong thực tế.",
                Content = """
## Câu Lệnh Điều Kiện

### if - else if - else
```java
int score = 75;

if (score >= 90) {
    System.out.println("Xuất sắc");
} else if (score >= 70) {
    System.out.println("Khá");
} else if (score >= 50) {
    System.out.println("Trung bình");
} else {
    System.out.println("Yếu");
}
```

### switch - case
```java
int day = 3;
switch (day) {
    case 1: System.out.println("Thứ Hai"); break;
    case 2: System.out.println("Thứ Ba");  break;
    case 3: System.out.println("Thứ Tư");  break;
    default: System.out.println("Ngày khác");
}
```

### Switch Expression (Java 14+)
```java
String result = switch (day) {
    case 1 -> "Thứ Hai";
    case 2 -> "Thứ Ba";
    case 3 -> "Thứ Tư";
    default -> "Ngày khác";
};
```
""" },

            new() { Id = "lesson-jb-4", TopicId = "topic-java-basics", Title = "Vòng Lặp", Order = 4, XpReward = 15, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "for, while, do-while và vòng lặp nâng cao với break/continue.",
                Content = """
## Vòng Lặp trong Java

### for loop
```java
for (int i = 0; i < 5; i++) {
    System.out.println("Lần " + i);
}
```

### while loop
```java
int i = 0;
while (i < 5) {
    System.out.println(i);
    i++;
}
```

### do-while loop
```java
int i = 0;
do {
    System.out.println(i);
    i++;
} while (i < 5);
// Luôn chạy ít nhất 1 lần
```

### for-each loop (Enhanced for)
```java
int[] numbers = {1, 2, 3, 4, 5};
for (int n : numbers) {
    System.out.println(n);
}
```

### break và continue
```java
for (int i = 0; i < 10; i++) {
    if (i == 3) continue; // bỏ qua i=3
    if (i == 7) break;    // thoát khi i=7
    System.out.println(i);
}
```
""" },

            // OOP
            new() { Id = "lesson-oop-1", TopicId = "topic-oop", Title = "Class và Object", Order = 1, XpReward = 10, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "Định nghĩa class, tạo object, constructor và từ khóa this.",
                Content = """
## Class và Object trong Java

### Định nghĩa Class
```java
public class Car {
    // Fields (thuộc tính)
    private String brand;
    private int year;
    private double speed;

    // Constructor
    public Car(String brand, int year) {
        this.brand = brand;
        this.year = year;
        this.speed = 0;
    }

    // Methods (phương thức)
    public void accelerate(double amount) {
        this.speed += amount;
    }

    public String getInfo() {
        return brand + " (" + year + ") - " + speed + " km/h";
    }
}
```

### Tạo và sử dụng Object
```java
Car myCar = new Car("Toyota", 2023);
myCar.accelerate(60);
System.out.println(myCar.getInfo());
// Toyota (2023) - 60.0 km/h
```

### Constructor Overloading
```java
public Car(String brand) {
    this(brand, 2024); // gọi constructor khác
}
```
""" },

            new() { Id = "lesson-oop-2", TopicId = "topic-oop", Title = "Đóng Gói (Encapsulation)", Order = 2, XpReward = 10, EstimatedMinutes = 12, IsActive = true, CreatedAt = now,
                Summary = "Access modifier, getter/setter và nguyên tắc ẩn dữ liệu.",
                Content = """
## Đóng Gói (Encapsulation)

Đóng gói là việc **ẩn dữ liệu** bên trong class và chỉ cung cấp các phương thức để truy cập có kiểm soát.

### Access Modifiers
| Modifier    | Class | Package | Subclass | World |
|-------------|-------|---------|----------|-------|
| `public`    | ✅    | ✅      | ✅       | ✅    |
| `protected` | ✅    | ✅      | ✅       | ❌    |
| (default)   | ✅    | ✅      | ❌       | ❌    |
| `private`   | ✅    | ❌      | ❌       | ❌    |

### Getter và Setter
```java
public class BankAccount {
    private double balance;
    private String owner;

    public double getBalance() {
        return balance;
    }

    public void deposit(double amount) {
        if (amount > 0) {
            balance += amount;
        }
    }

    public void withdraw(double amount) {
        if (amount > 0 && amount <= balance) {
            balance -= amount;
        } else {
            throw new IllegalArgumentException("Số tiền không hợp lệ");
        }
    }
}
```
""" },

            new() { Id = "lesson-oop-3", TopicId = "topic-oop", Title = "Kế Thừa (Inheritance)", Order = 3, XpReward = 15, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "extends, super, override và chuỗi kế thừa trong Java.",
                Content = """
## Kế Thừa (Inheritance)

### Định nghĩa lớp cha
```java
public class Animal {
    protected String name;
    protected int age;

    public Animal(String name, int age) {
        this.name = name;
        this.age = age;
    }

    public void eat() {
        System.out.println(name + " đang ăn");
    }

    public String describe() {
        return name + ", " + age + " tuổi";
    }
}
```

### Kế thừa với extends
```java
public class Dog extends Animal {
    private String breed;

    public Dog(String name, int age, String breed) {
        super(name, age); // gọi constructor cha
        this.breed = breed;
    }

    // Override phương thức cha
    @Override
    public String describe() {
        return super.describe() + ", giống: " + breed;
    }

    public void bark() {
        System.out.println(name + ": Gâu gâu!");
    }
}
```

### Sử dụng
```java
Dog dog = new Dog("Buddy", 3, "Golden Retriever");
dog.eat();       // kế thừa từ Animal
dog.bark();      // phương thức riêng
System.out.println(dog.describe());
```
""" },

            new() { Id = "lesson-oop-4", TopicId = "topic-oop", Title = "Đa Hình (Polymorphism)", Order = 4, XpReward = 15, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "Overriding, overloading, interface và abstract class.",
                Content = """
## Đa Hình (Polymorphism)

### Interface
```java
public interface Shape {
    double area();
    double perimeter();

    default String describe() {
        return "Diện tích: " + area();
    }
}
```

### Implement Interface
```java
public class Circle implements Shape {
    private double radius;

    public Circle(double radius) {
        this.radius = radius;
    }

    @Override
    public double area() {
        return Math.PI * radius * radius;
    }

    @Override
    public double perimeter() {
        return 2 * Math.PI * radius;
    }
}

public class Rectangle implements Shape {
    private double width, height;

    public Rectangle(double width, double height) {
        this.width = width;
        this.height = height;
    }

    @Override
    public double area() { return width * height; }

    @Override
    public double perimeter() { return 2 * (width + height); }
}
```

### Đa hình tại runtime
```java
List<Shape> shapes = List.of(
    new Circle(5),
    new Rectangle(4, 6)
);

for (Shape s : shapes) {
    System.out.println(s.describe()); // gọi đúng implementation
}
```
""" },

            // Collections
            new() { Id = "lesson-col-1", TopicId = "topic-collections", Title = "ArrayList và LinkedList", Order = 1, XpReward = 10, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "Sử dụng List interface, so sánh ArrayList vs LinkedList.",
                Content = """
## ArrayList và LinkedList

### ArrayList — truy cập nhanh theo index
```java
import java.util.ArrayList;
import java.util.List;

List<String> fruits = new ArrayList<>();
fruits.add("Táo");
fruits.add("Chuối");
fruits.add("Cam");

System.out.println(fruits.get(0));   // Táo
System.out.println(fruits.size());   // 3

fruits.remove("Chuối");
fruits.set(0, "Xoài");

// Duyệt
for (String fruit : fruits) {
    System.out.println(fruit);
}
```

### LinkedList — thêm/xóa đầu/cuối nhanh
```java
import java.util.LinkedList;

LinkedList<Integer> queue = new LinkedList<>();
queue.addFirst(1);
queue.addLast(2);
queue.addLast(3);

System.out.println(queue.removeFirst()); // 1
System.out.println(queue.peekLast());    // 3
```

### So sánh
| Thao tác         | ArrayList | LinkedList |
|------------------|-----------|------------|
| get(index)       | O(1) ✅   | O(n) ❌    |
| add(cuối)        | O(1)      | O(1)       |
| add(giữa)        | O(n) ❌   | O(1) ✅    |
| remove(index)    | O(n)      | O(n)       |
""" },

            new() { Id = "lesson-col-2", TopicId = "topic-collections", Title = "HashMap và HashSet", Order = 2, XpReward = 10, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "Lưu trữ key-value với Map và tập hợp không trùng lặp với Set.",
                Content = """
## HashMap và HashSet

### HashMap — key-value pairs
```java
import java.util.HashMap;
import java.util.Map;

Map<String, Integer> scores = new HashMap<>();
scores.put("Alice", 95);
scores.put("Bob", 87);
scores.put("Charlie", 92);

System.out.println(scores.get("Alice"));         // 95
System.out.println(scores.getOrDefault("Dan", 0)); // 0

// Duyệt
for (Map.Entry<String, Integer> entry : scores.entrySet()) {
    System.out.println(entry.getKey() + ": " + entry.getValue());
}

// Kiểm tra
scores.containsKey("Bob");    // true
scores.containsValue(100);    // false
scores.remove("Bob");
```

### HashSet — không trùng lặp
```java
import java.util.HashSet;
import java.util.Set;

Set<String> tags = new HashSet<>();
tags.add("java");
tags.add("oop");
tags.add("java"); // bị bỏ qua — trùng lặp

System.out.println(tags.size()); // 2
System.out.println(tags.contains("oop")); // true
```
""" },

            new() { Id = "lesson-col-3", TopicId = "topic-collections", Title = "Generics", Order = 3, XpReward = 15, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "Viết code tái sử dụng với Generic class và Generic method.",
                Content = """
## Generics trong Java

### Tại sao cần Generics?
```java
// Không dùng Generics — unsafe
List list = new ArrayList();
list.add("text");
list.add(123);
String s = (String) list.get(1); // ClassCastException!

// Dùng Generics — type-safe
List<String> strings = new ArrayList<>();
strings.add("text");
// strings.add(123); // compile error ngay
```

### Generic Class
```java
public class Pair<A, B> {
    private A first;
    private B second;

    public Pair(A first, B second) {
        this.first = first;
        this.second = second;
    }

    public A getFirst() { return first; }
    public B getSecond() { return second; }
}

// Sử dụng
Pair<String, Integer> p = new Pair<>("tuổi", 25);
System.out.println(p.getFirst() + ": " + p.getSecond());
```

### Generic Method
```java
public static <T extends Comparable<T>> T max(T a, T b) {
    return a.compareTo(b) >= 0 ? a : b;
}

System.out.println(max(10, 20));       // 20
System.out.println(max("abc", "xyz")); // xyz
```
""" },

            // Exception Handling
            new() { Id = "lesson-ex-1", TopicId = "topic-exception", Title = "try-catch-finally", Order = 1, XpReward = 10, EstimatedMinutes = 12, IsActive = true, CreatedAt = now,
                Summary = "Bắt và xử lý ngoại lệ cơ bản với try-catch-finally.",
                Content = """
## try - catch - finally

### Cú pháp cơ bản
```java
try {
    int result = 10 / 0; // ArithmeticException
    System.out.println(result);
} catch (ArithmeticException e) {
    System.out.println("Lỗi: " + e.getMessage());
} finally {
    System.out.println("Luôn chạy dù có lỗi hay không");
}
```

### Bắt nhiều loại ngoại lệ
```java
try {
    String s = null;
    System.out.println(s.length()); // NullPointerException
} catch (NullPointerException e) {
    System.out.println("Biến null!");
} catch (Exception e) {
    System.out.println("Lỗi khác: " + e.getMessage());
}
```

### Multi-catch (Java 7+)
```java
try {
    // code
} catch (IOException | SQLException e) {
    System.out.println("IO hoặc SQL error: " + e);
}
```

### try-with-resources (tự đóng resource)
```java
try (FileReader fr = new FileReader("file.txt");
     BufferedReader br = new BufferedReader(fr)) {
    String line = br.readLine();
    System.out.println(line);
} catch (IOException e) {
    e.printStackTrace();
}
// fr và br tự động đóng
```
""" },

            new() { Id = "lesson-ex-2", TopicId = "topic-exception", Title = "Checked vs Unchecked Exception", Order = 2, XpReward = 10, EstimatedMinutes = 12, IsActive = true, CreatedAt = now,
                Summary = "Phân biệt checked exception, unchecked exception và Error.",
                Content = """
## Checked vs Unchecked Exception

### Hierarchy
```
Throwable
├── Error (không nên bắt)
│   ├── OutOfMemoryError
│   └── StackOverflowError
└── Exception
    ├── Checked Exception (phải xử lý)
    │   ├── IOException
    │   ├── SQLException
    │   └── ClassNotFoundException
    └── RuntimeException (Unchecked)
        ├── NullPointerException
        ├── ArrayIndexOutOfBoundsException
        └── IllegalArgumentException
```

### Checked Exception — bắt buộc xử lý
```java
// Compiler báo lỗi nếu không xử lý
public void readFile(String path) throws IOException {
    FileReader fr = new FileReader(path); // checked
}
```

### Unchecked Exception — không bắt buộc
```java
public int divide(int a, int b) {
    if (b == 0) throw new ArithmeticException("Chia cho 0");
    return a / b;
}
```

### Quy tắc chung
- **Checked**: lỗi có thể dự đoán, người dùng nên xử lý (file không tồn tại, mất kết nối mạng)
- **Unchecked**: lỗi lập trình, nên fix code thay vì bắt (null pointer, index out of bounds)
""" },

            new() { Id = "lesson-ex-3", TopicId = "topic-exception", Title = "Custom Exception", Order = 3, XpReward = 15, EstimatedMinutes = 12, IsActive = true, CreatedAt = now,
                Summary = "Tạo exception tùy chỉnh và cách sử dụng trong ứng dụng thực tế.",
                Content = """
## Custom Exception

### Tạo Checked Custom Exception
```java
public class InsufficientFundsException extends Exception {
    private double amount;

    public InsufficientFundsException(double amount) {
        super("Không đủ tiền. Thiếu: " + amount);
        this.amount = amount;
    }

    public double getAmount() {
        return amount;
    }
}
```

### Tạo Unchecked Custom Exception
```java
public class ValidationException extends RuntimeException {
    private String field;

    public ValidationException(String field, String message) {
        super("Lỗi field '" + field + "': " + message);
        this.field = field;
    }

    public String getField() { return field; }
}
```

### Sử dụng trong thực tế
```java
public class BankAccount {
    private double balance;

    public void withdraw(double amount) throws InsufficientFundsException {
        if (amount > balance) {
            throw new InsufficientFundsException(amount - balance);
        }
        balance -= amount;
    }
}

// Gọi
try {
    account.withdraw(1000);
} catch (InsufficientFundsException e) {
    System.out.println(e.getMessage());
    System.out.println("Cần thêm: " + e.getAmount());
}
```
""" },

            // Streams
            new() { Id = "lesson-str-1", TopicId = "topic-streams", Title = "Lambda Expression", Order = 1, XpReward = 10, EstimatedMinutes = 15, IsActive = true, CreatedAt = now,
                Summary = "Cú pháp lambda, functional interface và method reference.",
                Content = """
## Lambda Expression

Lambda cho phép viết hàm ngắn gọn, truyền function như tham số.

### Cú pháp
```java
// Traditional (anonymous class)
Runnable r1 = new Runnable() {
    @Override
    public void run() {
        System.out.println("Hello");
    }
};

// Lambda
Runnable r2 = () -> System.out.println("Hello");

// Với tham số
Comparator<String> comp = (a, b) -> a.compareTo(b);

// Với body nhiều dòng
Comparator<Integer> comp2 = (a, b) -> {
    if (a > b) return 1;
    if (a < b) return -1;
    return 0;
};
```

### Functional Interface phổ biến
```java
// Predicate<T>: T -> boolean
Predicate<String> isEmpty = s -> s.isEmpty();
Predicate<Integer> isPositive = n -> n > 0;

// Function<T, R>: T -> R
Function<String, Integer> toLength = s -> s.length();
Function<Integer, String> toStr = n -> "Number: " + n;

// Consumer<T>: T -> void
Consumer<String> printer = s -> System.out.println(s);

// Supplier<T>: () -> T
Supplier<List<String>> listMaker = () -> new ArrayList<>();
```

### Method Reference
```java
// Instance method
list.forEach(System.out::println);

// Static method
list.stream().map(Integer::parseInt);

// Constructor
Supplier<ArrayList<String>> s = ArrayList::new;
```
""" },

            new() { Id = "lesson-str-2", TopicId = "topic-streams", Title = "Stream API Cơ Bản", Order = 2, XpReward = 15, EstimatedMinutes = 20, IsActive = true, CreatedAt = now,
                Summary = "filter, map, collect và các thao tác cơ bản với Stream.",
                Content = """
## Stream API

Stream cho phép xử lý collections theo phong cách hàm, pipeline.

### Tạo Stream
```java
List<Integer> numbers = List.of(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

// Từ Collection
Stream<Integer> s1 = numbers.stream();

// Từ Array
IntStream s2 = IntStream.range(1, 11);

// Từ giá trị
Stream<String> s3 = Stream.of("a", "b", "c");
```

### Các thao tác trung gian (Intermediate)
```java
List<String> names = List.of("Alice", "Bob", "Charlie", "David", "Eve");

List<String> result = names.stream()
    .filter(n -> n.length() > 3)        // lọc tên > 3 ký tự
    .map(String::toUpperCase)            // chuyển hoa
    .sorted()                            // sắp xếp
    .collect(Collectors.toList());       // thu thập

// [ALICE, CHARLIE, DAVID]
```

### Thao tác kết thúc (Terminal)
```java
// count
long count = numbers.stream().filter(n -> n % 2 == 0).count(); // 5

// sum, average
int sum = numbers.stream().mapToInt(Integer::intValue).sum();
OptionalDouble avg = numbers.stream().mapToInt(Integer::intValue).average();

// findFirst
Optional<Integer> first = numbers.stream().filter(n -> n > 5).findFirst();

// anyMatch, allMatch, noneMatch
boolean anyEven = numbers.stream().anyMatch(n -> n % 2 == 0); // true
boolean allPos  = numbers.stream().allMatch(n -> n > 0);       // true
```
""" },

            new() { Id = "lesson-str-3", TopicId = "topic-streams", Title = "Stream API Nâng Cao", Order = 3, XpReward = 20, EstimatedMinutes = 20, IsActive = true, CreatedAt = now,
                Summary = "groupingBy, reduce, flatMap và Collectors nâng cao.",
                Content = """
## Stream API Nâng Cao

### groupingBy
```java
List<String> words = List.of("apple", "banana", "avocado", "blueberry", "cherry");

Map<Character, List<String>> grouped = words.stream()
    .collect(Collectors.groupingBy(w -> w.charAt(0)));
// {a=[apple, avocado], b=[banana, blueberry], c=[cherry]}

// Đếm theo nhóm
Map<Character, Long> counts = words.stream()
    .collect(Collectors.groupingBy(w -> w.charAt(0), Collectors.counting()));
```

### reduce
```java
List<Integer> nums = List.of(1, 2, 3, 4, 5);

int product = nums.stream()
    .reduce(1, (a, b) -> a * b); // 120

Optional<Integer> max = nums.stream()
    .reduce(Integer::max); // 5
```

### flatMap
```java
List<List<Integer>> nested = List.of(
    List.of(1, 2, 3),
    List.of(4, 5),
    List.of(6, 7, 8)
);

List<Integer> flat = nested.stream()
    .flatMap(List::stream)
    .collect(Collectors.toList());
// [1, 2, 3, 4, 5, 6, 7, 8]
```

### joining
```java
String result = Stream.of("Java", "là", "ngôn ngữ", "mạnh")
    .collect(Collectors.joining(" "));
// "Java là ngôn ngữ mạnh"
```
""" },
        };

        // ── Questions ─────────────────────────────────────────────────────────
        var questions = new List<Question>
        {
            // Bài 1: Biến và Kiểu Dữ Liệu
            new() { Id = "q-jb1-1", LessonId = "lesson-jb-1", Order = 1, Points = 10,
                QuestionText = "Kiểu dữ liệu nào có kích thước 64-bit trong Java?",
                Options = new() { "int", "long", "short", "byte" },
                CorrectAnswerIndex = 1,
                Explanation = "long là kiểu nguyên 64-bit, có thể lưu giá trị từ -2^63 đến 2^63-1. int chỉ 32-bit." },

            new() { Id = "q-jb1-2", LessonId = "lesson-jb-1", Order = 2, Points = 10,
                QuestionText = "Từ khóa nào dùng để khai báo hằng số trong Java?",
                Options = new() { "const", "static", "final", "readonly" },
                CorrectAnswerIndex = 2,
                Explanation = "Java dùng 'final' để khai báo hằng số. 'const' là từ khóa dành riêng nhưng không dùng trong Java." },

            new() { Id = "q-jb1-3", LessonId = "lesson-jb-1", Order = 3, Points = 10,
                QuestionText = "Kiểu dữ liệu String trong Java là:",
                Options = new() { "Kiểu nguyên thủy (primitive)", "Kiểu tham chiếu (reference)", "Kiểu số nguyên", "Kiểu boolean" },
                CorrectAnswerIndex = 1,
                Explanation = "String là kiểu tham chiếu (reference type), là một class trong Java, không phải kiểu nguyên thủy." },

            // Bài 2: Toán Tử
            new() { Id = "q-jb2-1", LessonId = "lesson-jb-2", Order = 1, Points = 10,
                QuestionText = "Kết quả của `10 % 3` trong Java là bao nhiêu?",
                Options = new() { "0", "1", "3", "3.33" },
                CorrectAnswerIndex = 1,
                Explanation = "Toán tử % là chia lấy dư. 10 chia 3 được 3 dư 1, nên kết quả là 1." },

            new() { Id = "q-jb2-2", LessonId = "lesson-jb-2", Order = 2, Points = 10,
                QuestionText = "Kết quả của `int x = 5; x++; System.out.println(x);` là gì?",
                Options = new() { "4", "5", "6", "Lỗi compile" },
                CorrectAnswerIndex = 2,
                Explanation = "x++ là toán tử hậu tố, tăng x lên 1. Sau x++, x = 6. println in ra 6." },

            new() { Id = "q-jb2-3", LessonId = "lesson-jb-2", Order = 3, Points = 10,
                QuestionText = "Biểu thức nào sau đây trả về `true`?",
                Options = new() { "5 > 10 && 3 < 7", "5 > 10 || 3 < 7", "!(5 < 10)", "5 == 6" },
                CorrectAnswerIndex = 1,
                Explanation = "5 > 10 là false, 3 < 7 là true. false || true = true. Đáp án B đúng." },

            // Bài 3: Điều Kiện
            new() { Id = "q-jb3-1", LessonId = "lesson-jb-3", Order = 1, Points = 10,
                QuestionText = "Câu lệnh `switch` trong Java không thể dùng với kiểu dữ liệu nào?",
                Options = new() { "int", "String", "double", "char" },
                CorrectAnswerIndex = 2,
                Explanation = "switch không hỗ trợ kiểu dấu phẩy động (double, float) vì không so sánh chính xác được." },

            new() { Id = "q-jb3-2", LessonId = "lesson-jb-3", Order = 2, Points = 10,
                QuestionText = "Từ khóa nào dùng để thoát khỏi một case trong switch?",
                Options = new() { "exit", "return", "break", "continue" },
                CorrectAnswerIndex = 2,
                Explanation = "break dùng để thoát khỏi switch-case. Nếu không có break, chương trình sẽ 'fall through' sang case tiếp theo." },

            new() { Id = "q-jb3-3", LessonId = "lesson-jb-3", Order = 3, Points = 10,
                QuestionText = "Toán tử tam phân `(a > b) ? a : b` trả về gì khi a=3, b=7?",
                Options = new() { "3", "7", "true", "false" },
                CorrectAnswerIndex = 1,
                Explanation = "a > b là 3 > 7 = false, nên biểu thức trả về giá trị thứ hai là b = 7." },

            // Bài 4: Vòng Lặp
            new() { Id = "q-jb4-1", LessonId = "lesson-jb-4", Order = 1, Points = 10,
                QuestionText = "Vòng lặp nào đảm bảo luôn chạy ít nhất một lần?",
                Options = new() { "for", "while", "do-while", "for-each" },
                CorrectAnswerIndex = 2,
                Explanation = "do-while kiểm tra điều kiện SAU khi thực thi, nên body luôn chạy ít nhất 1 lần." },

            new() { Id = "q-jb4-2", LessonId = "lesson-jb-4", Order = 2, Points = 10,
                QuestionText = "Từ khóa nào dùng để bỏ qua một vòng lặp và tiếp tục vòng tiếp theo?",
                Options = new() { "break", "skip", "continue", "next" },
                CorrectAnswerIndex = 2,
                Explanation = "continue bỏ qua phần còn lại của body vòng lặp hiện tại và chuyển sang lần lặp tiếp theo." },

            new() { Id = "q-jb4-3", LessonId = "lesson-jb-4", Order = 3, Points = 15,
                QuestionText = "Vòng lặp `for (int i = 0; i < 5; i++)` chạy bao nhiêu lần?",
                Options = new() { "4 lần", "5 lần", "6 lần", "Vô hạn" },
                CorrectAnswerIndex = 1,
                Explanation = "i chạy từ 0 đến 4 (i < 5), tổng cộng 5 lần (i = 0, 1, 2, 3, 4)." },

            // OOP Questions
            new() { Id = "q-oop1-1", LessonId = "lesson-oop-1", Order = 1, Points = 10,
                QuestionText = "Phương thức đặc biệt được gọi khi tạo object là gì?",
                Options = new() { "destructor", "initializer", "constructor", "factory" },
                CorrectAnswerIndex = 2,
                Explanation = "Constructor là phương thức đặc biệt có cùng tên với class, được gọi khi tạo object bằng new." },

            new() { Id = "q-oop1-2", LessonId = "lesson-oop-1", Order = 2, Points = 10,
                QuestionText = "Từ khóa `this` trong Java dùng để:",
                Options = new() { "Tạo object mới", "Tham chiếu đến instance hiện tại", "Gọi class cha", "Khai báo static" },
                CorrectAnswerIndex = 1,
                Explanation = "this tham chiếu đến instance hiện tại của class, dùng để phân biệt field với tham số cùng tên." },

            new() { Id = "q-oop2-1", LessonId = "lesson-oop-2", Order = 1, Points = 10,
                QuestionText = "Access modifier nào cho phép truy cập từ mọi nơi?",
                Options = new() { "private", "protected", "default", "public" },
                CorrectAnswerIndex = 3,
                Explanation = "public cho phép truy cập từ bất kỳ class nào trong bất kỳ package nào." },

            new() { Id = "q-oop3-1", LessonId = "lesson-oop-3", Order = 1, Points = 10,
                QuestionText = "Từ khóa dùng để kế thừa class trong Java là gì?",
                Options = new() { "implements", "extends", "inherits", "super" },
                CorrectAnswerIndex = 1,
                Explanation = "extends dùng để kế thừa class. implements dùng cho interface." },

            new() { Id = "q-oop3-2", LessonId = "lesson-oop-3", Order = 2, Points = 10,
                QuestionText = "Annotation nào dùng để đánh dấu phương thức override?",
                Options = new() { "@Override", "@Inherit", "@Super", "@Redefine" },
                CorrectAnswerIndex = 0,
                Explanation = "@Override giúp compiler kiểm tra xem phương thức có thực sự override phương thức cha không." },

            new() { Id = "q-oop4-1", LessonId = "lesson-oop-4", Order = 1, Points = 10,
                QuestionText = "Interface trong Java có thể chứa:",
                Options = new() { "Chỉ abstract method", "Chỉ static method", "Abstract method và default method", "Constructor" },
                CorrectAnswerIndex = 2,
                Explanation = "Từ Java 8, interface có thể có default method (có body) và static method, ngoài abstract method." },

            // Collections Questions
            new() { Id = "q-col1-1", LessonId = "lesson-col-1", Order = 1, Points = 10,
                QuestionText = "Cấu trúc dữ liệu nào có thời gian truy cập theo index là O(1)?",
                Options = new() { "LinkedList", "ArrayList", "HashSet", "TreeSet" },
                CorrectAnswerIndex = 1,
                Explanation = "ArrayList lưu dữ liệu trong mảng liên tục, nên truy cập theo index là O(1). LinkedList cần duyệt O(n)." },

            new() { Id = "q-col2-1", LessonId = "lesson-col-2", Order = 1, Points = 10,
                QuestionText = "HashSet trong Java:",
                Options = new() { "Cho phép phần tử trùng lặp", "Không cho phép phần tử trùng lặp", "Duy trì thứ tự thêm vào", "Cho phép null không giới hạn" },
                CorrectAnswerIndex = 1,
                Explanation = "HashSet implement Set interface, không cho phép phần tử trùng lặp (dựa trên equals và hashCode)." },

            new() { Id = "q-col3-1", LessonId = "lesson-col-3", Order = 1, Points = 10,
                QuestionText = "Ký hiệu nào dùng để khai báo Generics trong Java?",
                Options = new() { "(T)", "[T]", "<T>", "{T}" },
                CorrectAnswerIndex = 2,
                Explanation = "Java dùng dấu ngoặc nhọn <T> để khai báo type parameter trong Generics." },

            // Exception Questions
            new() { Id = "q-ex1-1", LessonId = "lesson-ex-1", Order = 1, Points = 10,
                QuestionText = "Khối `finally` trong try-catch-finally:",
                Options = new() { "Chỉ chạy khi có exception", "Chỉ chạy khi không có exception", "Luôn chạy dù có exception hay không", "Không bao giờ chạy" },
                CorrectAnswerIndex = 2,
                Explanation = "finally luôn được thực thi, thường dùng để giải phóng tài nguyên (đóng file, connection, v.v.)." },

            new() { Id = "q-ex2-1", LessonId = "lesson-ex-2", Order = 1, Points = 10,
                QuestionText = "NullPointerException là loại exception nào?",
                Options = new() { "Checked Exception", "Unchecked Exception", "Error", "Throwable" },
                CorrectAnswerIndex = 1,
                Explanation = "NullPointerException extends RuntimeException, nên là Unchecked Exception — không cần try-catch bắt buộc." },

            new() { Id = "q-ex3-1", LessonId = "lesson-ex-3", Order = 1, Points = 10,
                QuestionText = "Để tạo Checked Custom Exception, class cần kế thừa từ:",
                Options = new() { "RuntimeException", "Exception", "Error", "Throwable" },
                CorrectAnswerIndex = 1,
                Explanation = "Kế thừa Exception (không phải RuntimeException) tạo ra Checked Exception — caller phải xử lý." },

            // Stream Questions
            new() { Id = "q-str1-1", LessonId = "lesson-str-1", Order = 1, Points = 10,
                QuestionText = "Lambda expression `() -> System.out.println(\"Hi\")` implement interface nào?",
                Options = new() { "Callable", "Runnable", "Supplier", "Consumer" },
                CorrectAnswerIndex = 1,
                Explanation = "Runnable có method run() không có tham số và không trả về giá trị, khớp với () -> ..." },

            new() { Id = "q-str2-1", LessonId = "lesson-str-2", Order = 1, Points = 10,
                QuestionText = "Phương thức nào của Stream dùng để lọc phần tử?",
                Options = new() { "map()", "filter()", "collect()", "reduce()" },
                CorrectAnswerIndex = 1,
                Explanation = "filter() nhận Predicate và giữ lại các phần tử thỏa điều kiện. map() chuyển đổi kiểu." },

            new() { Id = "q-str3-1", LessonId = "lesson-str-3", Order = 1, Points = 10,
                QuestionText = "Phương thức nào dùng để gộp Stream of Stream thành Stream phẳng?",
                Options = new() { "merge()", "concat()", "flatMap()", "combine()" },
                CorrectAnswerIndex = 2,
                Explanation = "flatMap() nhận mỗi phần tử, ánh xạ nó thành Stream, rồi gộp tất cả Stream con thành một Stream duy nhất." },
        };

        // ── Code Snippets ─────────────────────────────────────────────────────
        var snippets = new List<CodeSnippet>
        {
            new() { Id = "cs-jb-1", TopicId = "topic-java-basics", Order = 1, XpReward = 10, IsActive = true, CreatedAt = now, Language = "java",
                Title = "Hello World & Biến",
                Description = "In ra màn hình thông tin cá nhân sử dụng các kiểu dữ liệu cơ bản.",
                ExpectedOutput = "Tên: Nguyễn Văn A\nTuổi: 20\nĐiểm GPA: 3.75\nSinh viên: true",
                Code = """
public class Main {
    public static void main(String[] args) {
        String name = "Nguyễn Văn A";
        int age = 20;
        double gpa = 3.75;
        boolean isStudent = true;

        System.out.println("Tên: " + name);
        System.out.println("Tuổi: " + age);
        System.out.println("Điểm GPA: " + gpa);
        System.out.println("Sinh viên: " + isStudent);
    }
}
""" },

            new() { Id = "cs-jb-2", TopicId = "topic-java-basics", Order = 2, XpReward = 15, IsActive = true, CreatedAt = now, Language = "java",
                Title = "FizzBuzz",
                Description = "In từ 1 đến 20. Nếu chia hết cho 3 in 'Fizz', chia hết cho 5 in 'Buzz', chia hết cho cả hai in 'FizzBuzz'.",
                ExpectedOutput = "1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz\n16\n17\nFizz\n19\nBuzz",
                Code = """
public class Main {
    public static void main(String[] args) {
        for (int i = 1; i <= 20; i++) {
            if (i % 15 == 0) {
                System.out.println("FizzBuzz");
            } else if (i % 3 == 0) {
                System.out.println("Fizz");
            } else if (i % 5 == 0) {
                System.out.println("Buzz");
            } else {
                System.out.println(i);
            }
        }
    }
}
""" },

            new() { Id = "cs-oop-1", TopicId = "topic-oop", Order = 1, XpReward = 15, IsActive = true, CreatedAt = now, Language = "java",
                Title = "Lớp BankAccount",
                Description = "Tạo lớp tài khoản ngân hàng với deposit, withdraw và kiểm tra số dư.",
                ExpectedOutput = "Số dư ban đầu: 1000000.0\nSau khi nạp 500000: 1500000.0\nSau khi rút 200000: 1300000.0\nRút thất bại: Số dư không đủ",
                Code = """
public class Main {
    static class BankAccount {
        private String owner;
        private double balance;

        public BankAccount(String owner, double initialBalance) {
            this.owner = owner;
            this.balance = initialBalance;
        }

        public void deposit(double amount) {
            if (amount > 0) balance += amount;
        }

        public boolean withdraw(double amount) {
            if (amount > 0 && amount <= balance) {
                balance -= amount;
                return true;
            }
            return false;
        }

        public double getBalance() { return balance; }
    }

    public static void main(String[] args) {
        BankAccount acc = new BankAccount("Nguyễn Văn A", 1_000_000);
        System.out.println("Số dư ban đầu: " + acc.getBalance());

        acc.deposit(500_000);
        System.out.println("Sau khi nạp 500000: " + acc.getBalance());

        acc.withdraw(200_000);
        System.out.println("Sau khi rút 200000: " + acc.getBalance());

        if (!acc.withdraw(5_000_000)) {
            System.out.println("Rút thất bại: Số dư không đủ");
        }
    }
}
""" },

            new() { Id = "cs-col-1", TopicId = "topic-collections", Order = 1, XpReward = 15, IsActive = true, CreatedAt = now, Language = "java",
                Title = "Đếm tần suất từ",
                Description = "Dùng HashMap để đếm số lần xuất hiện của mỗi từ trong câu.",
                ExpectedOutput = "java: 3\nlà: 2\nngôn: 1\nngữ: 1\nmạnh: 1\nvà: 1\nphổ: 1\nbiến: 1",
                Code = """
import java.util.*;

public class Main {
    public static void main(String[] args) {
        String sentence = "java là ngôn ngữ mạnh và java là phổ biến java";
        String[] words = sentence.split(" ");

        Map<String, Integer> freq = new LinkedHashMap<>();
        for (String word : words) {
            Integer count = freq.get(word);
            freq.put(word, count == null ? 1 : count + 1);
        }

        for (Map.Entry<String, Integer> e : freq.entrySet()) {
            System.out.println(e.getKey() + ": " + e.getValue());
        }
    }
}
""" },

            new() { Id = "cs-str-1", TopicId = "topic-streams", Order = 1, XpReward = 20, IsActive = true, CreatedAt = now, Language = "java",
                Title = "Stream - Lọc và Biến Đổi",
                Description = "Dùng Stream API để tìm các số chẵn, bình phương chúng và tính tổng.",
                ExpectedOutput = "Số chẵn: [2, 4, 6, 8, 10]\nBình phương: [4, 16, 36, 64, 100]\nTổng bình phương số chẵn: 220",
                Code = """
import java.util.*;
import java.util.stream.*;

public class Main {
    public static void main(String[] args) {
        List<Integer> numbers = Arrays.asList(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

        List<Integer> evens = numbers.stream()
            .filter(n -> n % 2 == 0)
            .collect(Collectors.toList());
        System.out.println("Số chẵn: " + evens);

        List<Integer> squares = evens.stream()
            .map(n -> n * n)
            .collect(Collectors.toList());
        System.out.println("Bình phương: " + squares);

        int sum = squares.stream().mapToInt(Integer::intValue).sum();
        System.out.println("Tổng bình phương số chẵn: " + sum);
    }
}
""" },
        };

        db.Topics.AddRange(topics);
        db.Lessons.AddRange(lessons);
        db.Questions.AddRange(questions);
        db.CodeSnippets.AddRange(snippets);
        await db.SaveChangesAsync();
    }
}
