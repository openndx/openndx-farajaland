import type {User as SludiUser} from "../types/user.sludi";
import {Button} from "@/components/ui/button";
import {Globe, User, Search, LogOut} from "lucide-react";
import {Link, useNavigate} from "react-router-dom";
import {useEffect, useState} from "react";

export function Header() {
    const [user, setUser] = useState<SludiUser | null>(null);
    const navigate = useNavigate();

    useEffect(() => {
        const loadUser = () => {
            try {
                const stored = localStorage.getItem("sludi_user");
                if (stored) {
                    setUser(JSON.parse(stored));
                } else {
                    setUser(null);
                }
            } catch (error) {
                console.error("Error parsing user data:", error);
            }
        };

        loadUser();

        window.addEventListener("auth-change", loadUser);
        return () => window.removeEventListener("auth-change", loadUser);
    }, []);

    const handleLogout = () => {
        localStorage.removeItem("sludi_user");
        setUser(null);
        navigate("/");
    };

    return (
        <header className="bg-white border-b border-border shadow-sm">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex items-center justify-between h-16">
                    {/* Logo and Title */}
                    <Link to="/">
                        <div className="flex items-center space-x-4">
                            <div className="flex-shrink-0">
                                <img src="/sri-lankan-coat-of-arms.png" alt="Sri Lankan Coat of Arms"
                                     className="h-10 w-10"/>
                            </div>
                            <div>
                                <h1 className="text-lg font-semibold text-foreground font-sans">Online Passport
                                    Application System</h1>
                                <p className="text-sm text-muted-foreground">Department of Immigration and
                                    Emigration</p>
                            </div>
                        </div>
                    </Link>

                    {/* Navigation and Language Options */}
                    <div className="flex items-center space-x-4">
                        <Button variant="ghost" size="sm" asChild>
                            <a href="/status" className="flex items-center">
                                <Search className="h-4 w-4 mr-2"/>
                                Track Status
                            </a>
                        </Button>

                        <Button variant="outline" size="sm" className="text-sm bg-transparent">
                            <Globe className="h-4 w-4 mr-2"/>
                            English
                        </Button>
                        <Button variant="outline" size="sm" className="text-sm bg-transparent">
                            සිංහල
                        </Button>
                        <Button variant="outline" size="sm" className="text-sm bg-transparent">
                            தமிழ்
                        </Button>
                        {user ? (
                            <div className="flex items-center space-x-2">
                                <Button variant="ghost" size="sm" className="pointer-events-none">
                                    <User className="h-4 w-4 mr-2"/>
                                    {user.name}
                                </Button>
                                <Button variant="ghost" size="sm" onClick={handleLogout} className="text-red-600 hover:text-red-700 hover:bg-red-50">
                                    <LogOut className="h-4 w-4 mr-1"/>
                                    Logout
                                </Button>
                            </div>
                        ) : (
                            <Link to="/login" className="flex items-center text-sm font-medium text-gray-700 hover:text-primary transition duration-150">
                                <User className="h-4 w-4 mr-2"/>
                                Login
                            </Link>
                        )}
                    </div>
                </div>
            </div>
        </header>
    )
}
