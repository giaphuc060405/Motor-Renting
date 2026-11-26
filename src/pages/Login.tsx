import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useMutation } from "@tanstack/react-query";
import { useDeviceDetect } from "../hooks/useDeviceDetect"
import UnsupportedDevice  from "../components/UnsupportedDevice"
import { signIn, type LoginCredentials } from "../services/loginService";


export default function Login() {
    const navigate = useNavigate();
    const [signInData, setSignInData] = useState({
        email: '',
        password: ''
    });

    const checkoutMutation = useMutation({
        mutationFn: ({ email, password}: LoginCredentials) => signIn(email, password),
        onError: (error) => {
            console.error('Error while signing in: ', error);
        }
    });

    useEffect(() => {
        if (checkoutMutation.isSuccess) {
            navigate('/home', { replace: true});
        }
    }, [checkoutMutation.isSuccess, navigate])

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const { name, value } = e.target;
        const field = name as keyof typeof signInData;
        setSignInData(prev => ({ ...prev, [field]: value}));
    }

    const handleLogin = (e: React.SubmitEvent) => {
        e.preventDefault();
        if (checkoutMutation.isPending) return;
        checkoutMutation.mutate({
            email: signInData.email,
            password: signInData.password
        })
    }

    const { isMobileOrTablet } = useDeviceDetect();
    if (isMobileOrTablet) {
        return <UnsupportedDevice />
    }



    return (
        <div className="min-h-screen flex flex-col">
            <main className="flex flex-1 flex-col max-w-dvh w-full mx-auto px-4 py-8 gap-30">
                <h1 className="text-5xl font-bold text-center">Motor Renting</h1>
                <form onSubmit={handleLogin} className="flex flex-col flex-1 gap-4">
                    <div className="mb-4">
                        <label className="block text-sm font-bold mb-1.5">Email</label>
                        <input type="email" name="email" value={signInData.email} onChange={handleInputChange}
                        className="w-full border border-stone-900 rounded-lg px-3 py-2 text-black focus:outline-none" />
        
                    </div>
                    <div className="mb-4">
                        <label className="block text-sm font-bold mb-1.5">Mật khẩu</label>
                        <input type="password" name="password" value={signInData.password} onChange={handleInputChange}
                        className="w-full border border-stone-900 rounded-lg px-3 py-2 text-black focus:outline-none" />
                    </div>
                    {checkoutMutation.isError && (
                        <div className="mb-4">
                            <p className="text-xs italic text-red-700 min-h-8">Email hoặc mật khẩu không đúng</p>
                        </div>
                    )}
                    <div className="mb-4 flex flex-col items-center">
                        <button type="submit" disabled={checkoutMutation.isPending} className="w-[20%] py-3 bg-[#0068EF]
                         text-white font-medium rounded-lg cursor-pointer text-center">
                            {checkoutMutation.isPending ? "Đang xử lý" : "Đăng nhập"}
                        </button>
                    </div>
                
                </form>
            </main>
        </div>
    )
}