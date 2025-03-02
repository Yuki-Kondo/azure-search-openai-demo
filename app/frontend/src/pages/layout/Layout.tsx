import { useState, useMemo } from "react";
import { Outlet, NavLink, Link } from "react-router-dom";
import { AccessToken, Claim } from "../../api";

import github from "../../assets/github.svg";

import styles from "./Layout.module.css";

const Layout = () => {
    const [loginUser, setLoginUser] = useState<string>("");

    const getLoginUserName = async () => {
        const loginUser: string = "";

        try {
            const result = await fetch("/.auth/me");

            const response: AccessToken[] = await result.json();
            const loginUserClaim = response[0].user_claims.find((claim: Claim) => claim.typ === "preferred_username");
            if (loginUserClaim) setLoginUser(loginUserClaim.val);
            else setLoginUser(response[0].user_id);
        } catch (e) {
            setLoginUser("anonymous");
        }
    };

    getLoginUserName();

    return (
        <div className={styles.layout}>
            <header className={styles.header} role={"banner"}>
                <div className={styles.headerContainer}>
                    <Link to="/" className={styles.headerTitleContainer}>
                        <h3 className={styles.headerTitle}>SAWAI AI Chat</h3>
                    </Link>
                    <nav>
                        <ul className={styles.headerNavList}>
                            <li>
                                <NavLink to="/" className={({ isActive }) => (isActive ? styles.headerNavPageLinkActive : styles.headerNavPageLink)}>
                                    企業内チャット
                                </NavLink>
                            </li>
                            <li className={styles.headerNavLeftMargin}>
                                <NavLink to="/qa" className={({ isActive }) => (isActive ? styles.headerNavPageLinkActive : styles.headerNavPageLink)}>
                                    AIチャット活用チュートリアル
                                </NavLink>
                            </li>
                            <li className={styles.headerNavLeftMargin}>
                                <a href="https://aka.ms/entgptsearch" target={"_blank"} title="Github repository link">
                                    <img
                                        src={github}
                                        alt="Github logo"
                                        aria-label="Link to github repository"
                                        width="20px"
                                        height="20px"
                                        className={styles.githubLogo}
                                    />
                                </a>
                            </li>
                        </ul>
                    </nav>
                    <h3 className={styles.headerRightText}>{loginUser}</h3>
                </div>
            </header>

            <Outlet />
        </div>
    );
};

export default Layout;
