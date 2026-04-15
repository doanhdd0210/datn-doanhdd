class CodeSnippet {
  final String title;
  final String description;
  final String code;

  const CodeSnippet({
    required this.title,
    required this.description,
    required this.code,
  });
}

const List<CodeSnippet> javaSnippets = [
  CodeSnippet(
    title: 'Hello World',
    description: 'Chương trình đầu tiên',
    code: '''public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}''',
  ),
  CodeSnippet(
    title: 'Fibonacci',
    description: 'Dãy số Fibonacci',
    code: '''public class Main {
    public static void main(String[] args) {
        int n = 10;
        int a = 0, b = 1;
        System.out.print("Fibonacci: ");
        for (int i = 0; i < n; i++) {
            System.out.print(a + " ");
            int temp = a + b;
            a = b;
            b = temp;
        }
        System.out.println();
    }
}''',
  ),
  CodeSnippet(
    title: 'Bubble Sort',
    description: 'Sắp xếp nổi bọt',
    code: '''public class Main {
    public static void main(String[] args) {
        int[] arr = {64, 34, 25, 12, 22, 11, 90};

        // Bubble sort
        int n = arr.length;
        for (int i = 0; i < n - 1; i++) {
            for (int j = 0; j < n - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    int temp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = temp;
                }
            }
        }

        System.out.print("Sorted: ");
        for (int x : arr) {
            System.out.print(x + " ");
        }
        System.out.println();
    }
}''',
  ),
  CodeSnippet(
    title: 'Đệ quy - Giai thừa',
    description: 'Tính n! bằng đệ quy',
    code: '''public class Main {
    static long factorial(int n) {
        if (n <= 1) return 1;
        return n * factorial(n - 1);
    }

    public static void main(String[] args) {
        for (int i = 0; i <= 10; i++) {
            System.out.println(i + "! = " + factorial(i));
        }
    }
}''',
  ),
  CodeSnippet(
    title: 'Kiểm tra số nguyên tố',
    description: 'Tìm số nguyên tố đến 50',
    code: '''public class Main {
    static boolean isPrime(int n) {
        if (n < 2) return false;
        for (int i = 2; i * i <= n; i++) {
            if (n % i == 0) return false;
        }
        return true;
    }

    public static void main(String[] args) {
        System.out.print("Số nguyên tố: ");
        for (int i = 2; i <= 50; i++) {
            if (isPrime(i)) System.out.print(i + " ");
        }
        System.out.println();
    }
}''',
  ),
  CodeSnippet(
    title: 'Stack - LIFO',
    description: 'Demo cấu trúc dữ liệu Stack',
    code: '''import java.util.Stack;

public class Main {
    public static void main(String[] args) {
        Stack<Integer> stack = new Stack<>();

        // Push
        System.out.println("Push: 10, 20, 30");
        stack.push(10);
        stack.push(20);
        stack.push(30);

        System.out.println("Top: " + stack.peek());

        // Pop all
        System.out.print("Pop: ");
        while (!stack.isEmpty()) {
            System.out.print(stack.pop() + " ");
        }
        System.out.println();
    }
}''',
  ),
];
