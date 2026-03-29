namespace Sample.Lib;

public class Bar
{
    public void Foo()
    {
        var c = new MyNugetPackage.MyClass();
        var text = c.GetMessage();
        Console.WriteLine(text);
    }
}
